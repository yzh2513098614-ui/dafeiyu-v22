param([string]$Project='D:\迅雷下载\大肥鱼_数值战斗怪物_v22')
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices; using System.Collections.Generic;
public class PortraitCutout {
 public static string Run(string src,string dst) {
 using(var input=new Bitmap(src)) using(var im=new Bitmap(input.Width,input.Height,PixelFormat.Format32bppArgb)) {
 using(var g=Graphics.FromImage(im)) g.DrawImageUnscaled(input,0,0);
 int w=im.Width,h=im.Height,n=w*h;var rect=new Rectangle(0,0,w,h);var bits=im.LockBits(rect,ImageLockMode.ReadWrite,PixelFormat.Format32bppArgb);byte[] p=new byte[n*4];Marshal.Copy(bits.Scan0,p,0,p.Length);
 bool[] white=new bool[n],seen=new bool[n],remove=new bool[n];
 for(int i=0;i<n;i++){int b=p[i*4],g=p[i*4+1],r=p[i*4+2];white[i]=Math.Min(r,Math.Min(g,b))>=235 && Math.Max(r,Math.Max(g,b))-Math.Min(r,Math.Min(g,b))<=18;}
 int holes=0,total=0;int[] q=new int[n];
 for(int seed=0;seed<n;seed++) {if(!white[seed]||seen[seed])continue;int head=0,tail=1;q[0]=seed;seen[seed]=true;bool edge=false;int blue=0,colored=0;
 while(head<tail){int a=q[head++],x=a%w,y=a/w;if(x==0||y==0||x==w-1||y==h-1)edge=true;
 for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){if(Math.Abs(dx)+Math.Abs(dy)!=1)continue;int xx=x+dx,yy=y+dy;if(xx<0||xx>=w||yy<0||yy>=h)continue;int z=yy*w+xx;if(white[z]){if(!seen[z]){seen[z]=true;q[tail++]=z;}}else {
 // Sample through antialiased outlines, counting only saturated boundary colors.
 for(int k=1;k<=5;k++){int bx=x+dx*k,by=y+dy*k;if(bx<0||bx>=w||by<0||by>=h)break;int j=(by*w+bx)*4;int b=p[j],g=p[j+1],r=p[j+2];if(Math.Max(r,Math.Max(g,b))-Math.Min(r,Math.Min(g,b))<35)continue;colored++;if(b>r+30 && b>g+8)blue++;break;}
 }} }
 double cx=0,cy=0;int minY=h;for(int k=0;k<tail;k++){cx+=q[k]%w;cy+=q[k]/w;minY=Math.Min(minY,q[k]/w);}cx/=tail*w;cy/=tail*h;bool hairZone=(cy<0.13 && (double)minY/h<0.10) || (cy>0.23 && cy<0.52 && (cx<0.29 || cx>0.79) || (cy>0.40 && cy<0.50 && (cx<0.34 || cx>0.74))) || (cy>=0.52 && cy<0.64 && (cx<0.20 || cx>0.86));bool cut=edge || (hairZone && tail>=80 && colored>=8 && (double)blue/colored>=(cy<0.13 ? 0.50 : 0.90));
 if(cut){if(!edge)holes++;for(int k=0;k<tail;k++){remove[q[k]]=true;total++;}}
 }
 // Keep original RGB and soften only near-white pixels touching the removed background.
 byte[] alpha=new byte[n];for(int i=0;i<n;i++)alpha[i]=(byte)(remove[i]?0:255);
 for(int y=1;y<h-1;y++)for(int x=1;x<w-1;x++){int i=y*w+x;if(remove[i])continue;bool near=remove[i-1]||remove[i+1]||remove[i-w]||remove[i+w];if(!near)continue;int j=i*4,min=Math.Min(p[j],Math.Min(p[j+1],p[j+2]));if(min>205 && Math.Max(p[j],Math.Max(p[j+1],p[j+2]))-min<28)alpha[i]=(byte)Math.Min(255,Math.Max(0,(255-min)*255/50));}
 for(int i=0;i<n;i++)p[i*4+3]=alpha[i];Marshal.Copy(p,0,bits.Scan0,p.Length);im.UnlockBits(bits);im.Save(dst,ImageFormat.Png);return w+"x"+h+", transparent_pixels="+total+", enclosed_hair_gaps="+holes;
 }
 }
}
"@
$dir=Join-Path $Project 'assets\dialogue\downloaded_20261014'
$out=Join-Path $dir 'transparent';New-Item -ItemType Directory -Force $out | Out-Null
$results=@();foreach($f in Get-ChildItem -LiteralPath $dir -Filter '*.png'){$r=[PortraitCutout]::Run($f.FullName,(Join-Path $out $f.Name));$results+="$($f.Name): $r";Write-Output $results[-1]}
$results | Set-Content -Encoding UTF8 (Join-Path $out 'cutout_report.txt')