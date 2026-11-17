$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.Drawing
if (-not ('JotItBrandExport' -as [type])) {
    Add-Type -ReferencedAssemblies @('System.Drawing.Common', 'System.Drawing.Primitives', 'System.Private.Windows.GdiPlus', 'System.Private.Windows.Core', 'System.Collections', 'System.Runtime', 'System.IO') -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.IO;

public static class JotItBrandExport {
    // Extract the approved symbol, keeping its enclosed white J intact.
    public static Bitmap Symbol(string source) {
        using (var image = new Bitmap(source)) {
            int left=image.Width, top=image.Height, right=0, bottom=0;
            for (int y=0; y<image.Height; y++) for (int x=0; x<image.Width; x++) {
                var c=image.GetPixel(x,y);
                if (c.B>160 && c.R>45 && c.R<200 && c.G<150 && c.B>c.R*1.2) {
                    left=Math.Min(left,x); top=Math.Min(top,y);
                    right=Math.Max(right,x); bottom=Math.Max(bottom,y);
                }
            }
            if (right<=left || bottom<=top) throw new Exception("Purple emblem not found.");
            left=Math.Max(0,left-2); top=Math.Max(0,top-2);
            right=Math.Min(image.Width-1,right+2); bottom=Math.Min(image.Height-1,bottom+2);
            var bounds=new Rectangle(left,top,right-left+1,bottom-top+1);
            var symbol=image.Clone(bounds,PixelFormat.Format32bppArgb);
            var pending=new Queue<Point>();
            for (int x=0;x<symbol.Width;x++) { pending.Enqueue(new Point(x,0)); pending.Enqueue(new Point(x,symbol.Height-1)); }
            for (int y=0;y<symbol.Height;y++) { pending.Enqueue(new Point(0,y)); pending.Enqueue(new Point(symbol.Width-1,y)); }
            while (pending.Count>0) {
                var p=pending.Dequeue();
                if (p.X<0 || p.Y<0 || p.X>=symbol.Width || p.Y>=symbol.Height) continue;
                var c=symbol.GetPixel(p.X,p.Y);
                if (c.A==0 || c.R<215 || c.G<215 || c.B<215) continue;
                symbol.SetPixel(p.X,p.Y,Color.Transparent);
                pending.Enqueue(new Point(p.X-1,p.Y)); pending.Enqueue(new Point(p.X+1,p.Y));
                pending.Enqueue(new Point(p.X,p.Y-1)); pending.Enqueue(new Point(p.X,p.Y+1));
            }
            return symbol;
        }
    }
    public static byte[] Png(Bitmap source,int size,double coverage,bool opaque) {
        using (var output=new Bitmap(size,size,PixelFormat.Format32bppArgb)) {
            using (var g=Graphics.FromImage(output)) {
                g.Clear(opaque ? Color.White : Color.Transparent);
                g.InterpolationMode=InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode=PixelOffsetMode.HighQuality;
                g.CompositingQuality=CompositingQuality.HighQuality;
                var scale=size*coverage/Math.Max(source.Width,source.Height);
                float w=(float)(source.Width*scale), h=(float)(source.Height*scale);
                g.DrawImage(source,new RectangleF((size-w)/2,(size-h)/2,w,h));
            }
            using(var stream=new MemoryStream()) { output.Save(stream,ImageFormat.Png); return stream.ToArray(); }
        }
    }
    public static void Ico(Bitmap source,string path) {
        var sizes=new int[]{16,24,32,48,64,128,256};
        var frames=new List<byte[]>();
        foreach(var size in sizes) frames.Add(Png(source,size,.9,false));
        using(var writer=new BinaryWriter(File.Create(path))) {
            writer.Write((ushort)0); writer.Write((ushort)1); writer.Write((ushort)sizes.Length);
            int offset=6+16*sizes.Length;
            for(int i=0;i<sizes.Length;i++) {
                writer.Write((byte)(sizes[i]==256?0:sizes[i])); writer.Write((byte)(sizes[i]==256?0:sizes[i]));
                writer.Write((byte)0); writer.Write((byte)0); writer.Write((ushort)1); writer.Write((ushort)32);
                writer.Write(frames[i].Length); writer.Write(offset); offset+=frames[i].Length;
            }
            foreach(var frame in frames) writer.Write(frame);
        }
    }
}
'@
}
$source = Join-Path $root 'assets/branding/jotit-geometric-purple-lockup.png'
$symbol = [JotItBrandExport]::Symbol($source)
try {
    $symbol.Save((Join-Path $root 'assets/branding/jotit-symbol.png'), [Drawing.Imaging.ImageFormat]::Png)
    [IO.File]::WriteAllBytes((Join-Path $root 'assets/branding/jotit-app-icon.png'), [JotItBrandExport]::Png($symbol,1024,0.72,$true))
    foreach ($size in @(192,512)) {
        [IO.File]::WriteAllBytes((Join-Path $root "web/icons/Icon-$size.png"), [JotItBrandExport]::Png($symbol,$size,0.72,$true))
        [IO.File]::WriteAllBytes((Join-Path $root "web/icons/Icon-maskable-$size.png"), [JotItBrandExport]::Png($symbol,$size,0.54,$true))
    }
    [IO.File]::WriteAllBytes((Join-Path $root 'web/icons/jotit-symbol.png'), [JotItBrandExport]::Png($symbol,192,0.98,$false))
    [IO.File]::WriteAllBytes((Join-Path $root 'web/favicon.png'), [JotItBrandExport]::Png($symbol,32,0.94,$false))
    $androidSizes = @{mdpi=48; hdpi=72; xhdpi=96; xxhdpi=144; xxxhdpi=192}
    foreach ($density in $androidSizes.Keys) {
        [IO.File]::WriteAllBytes((Join-Path $root "android/app/src/main/res/mipmap-$density/ic_launcher.png"), [JotItBrandExport]::Png($symbol,$androidSizes[$density],0.72,$true))
    }
    foreach ($platform in @('ios','macos')) {
        $iconDirectory = Join-Path $root "$platform/Runner/Assets.xcassets/AppIcon.appiconset"
        $catalog = Get-Content -LiteralPath (Join-Path $iconDirectory 'Contents.json') -Raw | ConvertFrom-Json
        foreach ($entry in $catalog.images) {
            $size = [int]([double]($entry.size.Split('x')[0]) * [double]$entry.scale.TrimEnd('x'))
            [IO.File]::WriteAllBytes((Join-Path $iconDirectory $entry.filename), [JotItBrandExport]::Png($symbol,$size,0.72,($platform -eq 'ios')))
        }
    }
    [JotItBrandExport]::Ico($symbol,(Join-Path $root 'windows/runner/resources/app_icon.ico'))
    Write-Output 'Exported the approved JotIt symbol, web/PWA, Android, iOS, macOS and Windows icons.'
} finally {
    $symbol.Dispose()
}
