package de.polygonal.zz.data;

#if flash
typedef ImageData = flash.display.BitmapData;
#elseif js
typedef ImageData = js.html.ImageElement;
#elseif nme
typedef ImageData = nme.display.BitmapData;
#end