import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../model/note_ai_plan.dart';
import '../model/note_sticker.dart';
import '../model/note_text_style.dart';
import '../model/note_ai_appearance.dart';
import 'firebase_note_ai.dart';
import 'gemini_anchors.dart';
import 'note_ai_request.dart';

class NoteAiService {
  NoteAiService({
    required this.token,
    http.Client? client,
    this.endpoint = const String.fromEnvironment('JOTIT_AI_URL'),
    this.firebaseGenerate,
    this.requestTimeout = const Duration(seconds: 60),
  }) : _client = client ?? http.Client();
  final Future<String?> Function() token;
  final String endpoint;
  final http.Client _client;
  final Future<String> Function(Map<String, dynamic>)? firebaseGenerate;
  final Duration requestTimeout;
  bool get configured =>
      endpoint.isNotEmpty ||
      firebaseGenerate != null ||
      FirebaseNoteAi.configured;
  Future<NoteAiPlan> generate({
    required String mode,
    required String prompt,
    required String text,
    List<Map<String, dynamic>> structure = const [],
    NoteAiAppearance? appearance,
    String scope = 'whole',
    NoteAiCancellation? cancellation,
    void Function(NoteAiStage)? onStage,
  }) async {
    final request = cancellation ?? NoteAiCancellation();
    void report(NoteAiStage stage) {
      request.check();
      onStage?.call(stage);
      request.check();
    }

    request.check();
    try {
      return await request
          .wait(
            _generate(
              mode: mode,
              prompt: prompt,
              text: text,
              structure: structure,
              appearance: appearance,
              scope: scope,
              report: report,
            ),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      request.cancel();
      throw const FormatException(
        'Gemini took too long. Your note and any previous preview are unchanged. Try again, or select a smaller section of a long note.',
      );
    } finally {
      // Release the cancellation listener when the operation has finished.
      if (cancellation == null) request.cancel();
    }
  }

  Future<NoteAiPlan> _generate({
    required String mode,
    required String prompt,
    required String text,
    List<Map<String, dynamic>> structure = const [],
    NoteAiAppearance? appearance,
    String scope = 'whole',
    required void Function(NoteAiStage) report,
  }) async {
    final uri = Uri.tryParse(endpoint);
    final local =
        kDebugMode &&
        uri?.scheme == 'http' &&
        ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri?.host);
    if (endpoint.isNotEmpty &&
        (uri == null ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            (uri.scheme != 'https' && !local))) {
      throw const FormatException(
        'Gemini is not connected for this build. Configure the AI backend first.',
      );
    }
    if (prompt.trim().isEmpty || prompt.length > 2000 || text.length > 50000) {
      throw const FormatException(
        'Use a shorter prompt or select a smaller part of the note.',
      );
    }
    report(NoteAiStage.checkingSession);
    String? auth;
    try {
      auth = await token();
    } catch (_) {
      throw const FormatException(
        'Could not verify your AI session. Check your connection and try again.',
      );
    }
    if (auth == null || auth.isEmpty) {
      throw const FormatException(
        'Sign in to your account to use Gemini assistance.',
      );
    }
    report(NoteAiStage.generating);
    if (endpoint.isEmpty) {
      try {
        final paragraphs = GeminiAnchors.paragraphs(text, structure)
            .map(
              (p) => Map<String, dynamic>.from(p)
                ..remove('start')
                ..remove('end'),
            )
            .toList();
        final input = <String, dynamic>{
          'version': 2,
          'scope': scope,
          'mode': mode,
          'prompt': prompt.trim(),
          'text': text,
          'paragraphs': paragraphs,
          if (appearance != null) 'appearance': appearance.toJson(),
          'styles': NoteTextStyles.presets
              .map(
                (s) => {
                  'id': s.id,
                  'name': s.name,
                  'category': s.category,
                  'attributes': s.attributes,
                },
              )
              .toList(),
          'catalog': StickerCatalog.formats
              .map(
                (f) => {
                  'id': f.id,
                  'name': f.name,
                  'kind': f.isDoodle ? 'doodle' : 'sticker',
                },
              )
              .toList(),
        };
        final budget = Stopwatch()..start();
        for (var attempt = 0; attempt < 2; attempt++) {
          final remaining = const Duration(seconds: 60) - budget.elapsed;
          if (remaining <= Duration.zero) {
            throw TimeoutException('AI generation timed out');
          }
          final result = await (firebaseGenerate ?? FirebaseNoteAi.generate)(
            input,
          ).timeout(remaining);
          report(NoteAiStage.checkingProposal);
          try {
            if (utf8.encode(result).length > 200000) {
              throw const FormatException(
                'Gemini returned too much content. Try a smaller request.',
              );
            }
            return GeminiAnchors.resolve(
              jsonDecode(result),
              text: text,
              mode: mode,
              scope: scope,
              prompt: prompt,
            );
          } on FormatException catch (error) {
            if (attempt == 1) {
              throw const FormatException(
                'Gemini returned edits that could not be applied safely, even after a correction. Your note and any previous preview are unchanged. Try a smaller selection, or ask for one change at a time.',
              );
            }
            // Send bounded validation guidance, never raw exception sources,
            // partial proposals, credentials or unrelated note content.
            final reason = error.source == null
                ? error.message.toString().substring(
                    0,
                    error.message.toString().length.clamp(0, 400),
                  )
                : 'Return a JSON object matching the response schema.';
            input['validationFeedback'] =
                'Validation failed: $reason Regenerate the COMPLETE proposal. '
                'Review every paragraph ID exactly once. Use only supplied catalog IDs; '
                'every sticker and doodle block requires formatId. Keep at most three accent colors. '
                '${mode == 'Format' ? 'Preserve all existing wording.' : 'Use insert edits to add new content, including on empty paragraphs.'} '
                'Preserve existing links and objects.';
            report(NoteAiStage.correcting);
          }
        }
        throw const FormatException('Gemini did not return a valid proposal.');
      } on NoteAiCancelled {
        rethrow;
      } on TimeoutException {
        throw const FormatException(
          'Gemini took too long. Your note is unchanged; try again.',
        );
      } on FormatException {
        rethrow;
      } catch (error) {
        throw FormatException(FirebaseNoteAi.errorMessage(error));
      }
    }
    http.Response response;
    try {
      response = await _client
          .post(
            uri!,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $auth',
            },
            body: jsonEncode({
              'version': 2,
              'scope': scope,
              'mode': mode,
              'prompt': prompt,
              'text': text,
              'structure': structure,
              if (appearance != null) 'appearance': appearance.toJson(),
              'styles': NoteTextStyles.presets
                  .map(
                    (s) => {
                      'id': s.id,
                      'name': s.name,
                      'category': s.category,
                      'attributes': s.attributes,
                    },
                  )
                  .toList(),
              'catalog': StickerCatalog.formats
                  .map(
                    (f) => {
                      'id': f.id,
                      'name': f.name,
                      'kind': f.isDoodle ? 'doodle' : 'sticker',
                    },
                  )
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const FormatException(
        'Gemini took too long. Your note is unchanged; try again.',
      );
    } catch (_) {
      throw const FormatException(
        'Could not reach Gemini. Check your connection and try again.',
      );
    }
    report(NoteAiStage.checkingProposal);
    if (response.statusCode == 429) {
      throw const FormatException(
        'Gemini’s free-tier quota is temporarily reached. Wait and try again.',
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const FormatException('Your AI session needs signing in again.');
    }
    if (response.statusCode != 200) {
      throw const FormatException(
        'Gemini could not complete this request. Your note is unchanged.',
      );
    }
    if (response.bodyBytes.length > 200000) {
      throw const FormatException(
        'Gemini returned too much content. Try a smaller request.',
      );
    }
    try {
      final value = jsonDecode(response.body);
      if (structure.isNotEmpty &&
          (value is! Map || value['anchored'] != true)) {
        throw const FormatException(
          'The AI backend needs an update. Your note is unchanged.',
        );
      }
      return NoteAiPlan.fromJson(value);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Gemini returned an invalid response. Please try again.',
      );
    }
  }

  void dispose() => _client.close();
}
