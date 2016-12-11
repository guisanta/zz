/*
Copyright (c) 2014 Michael Baczynski, http://www.polygonal.de

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
package de.polygonal.zz.texture;

import de.polygonal.core.math.Mathematics as M;
import de.polygonal.ds.Hashable;
import de.polygonal.zz.data.ImageData;
import de.polygonal.zz.data.Size.Sizei;
import de.polygonal.zz.texture.atlas.TextureAtlas;

#if flash
import de.polygonal.core.fmt.Ascii;
import flash.utils.ByteArray;
import flash.display3D.Context3DTextureFormat;
#end

class Texture implements Hashable
{
	public static var counter = 0;
	
	public var key(default, null):Int;
	
	public var imageData:ImageData = null;
	
	#if flash
	public var atfData:ByteArray = null;
	public var format = Context3DTextureFormat.BGRA;
	#end
	
	public var sourceSize(default, null) = new Sizei();
	public var paddedSize(default, null):Sizei;
	
	public var isAlphaPremultiplied = true;
	public var isCompressed = false;
	public var isPadded(default, null) = false;
	
	public var scale = 1.;
	
	public var atlas:TextureAtlas;
	
	public function new()
	{
		key = ++counter;
		paddedSize = sourceSize;
	}
	
	public function setImageData(data:ImageData, supportsNpot:Bool):Texture
	{
		imageData = data;
		
		sourceSize.set(data.width, data.height);
		
		if (!supportsNpot && !(M.isPow2(sourceSize.x) && M.isPow2(sourceSize.y)))
		{
			isPadded = true;
			paddedSize = new Sizei(M.nextPow2(sourceSize.x), M.nextPow2(sourceSize.y));
			
			/*
			    +========+     +========+====+
			    |        |     |        |    |
			    |        | ==> |        |    |
			    +========+     +========+    |
			                   |             |
			                   |             |
			                   +=============+
			*/
			#if flash
			var data = new flash.display.BitmapData(paddedSize.x, paddedSize.y, true, 0);
			data.copyPixels(imageData, imageData.rect, new flash.geom.Point());
			imageData = data;
			#elseif js
			var canvas = js.Browser.document.createCanvasElement();
			canvas.width = paddedSize.x;
			canvas.height = paddedSize.y;
			canvas.getContext("2d").drawImage(data, 0, 0);
			imageData = js.Browser.document.createImageElement();
			imageData.src = canvas.toDataURL("image/png");
			#end
		}
		
		return this;
	}
	
	#if flash
	public function setAtfData(data:flash.utils.ByteArray):Texture
	{
		if (data.length < 3 || data[0] != Ascii.A || data[1] != Ascii.T || data[2] != Ascii.F) throw "invalid ATF signature";
		
		var pos = data[6] == 255 ? 12 : 6;
		
		format =
		switch (data[pos] & 0x7f)
		{
			case  0 | 1: Context3DTextureFormat.BGRA;
			case  2 | 3 | 12: Context3DTextureFormat.COMPRESSED;
			case  4 | 5 | 13: Context3DTextureFormat.COMPRESSED_ALPHA;
			case _: throw "invalid ATF format";
		}
		
		atfData = data;
		
		sourceSize.set(1 << data[pos + 1], 1 << data[pos + 2]);
		
		var numTextures = data[pos + 3];
		var isCubeMap = data[pos] & 0x80 != 0;
		if (data[5] != 0 && data[6] == 255) //png2atf '-e', '-n'
		{
			var emptyMipmaps = (data[5] & 0x01) == 1;
			numTextures = emptyMipmaps ? 1 : data[5] >> 1 & 0x7f;
		}
		
		isCompressed = true;
		isAlphaPremultiplied = false;
		return this;
	}
	#end
	
	public function free()
	{
		if (isPadded && !isCompressed)
		{
			#if flash
			try
			{
				imageData.dispose();
			}
			catch(error:Dynamic)
			{
			}
			#elseif js
			imageData.src = "data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==";
			#end
		}
		
		imageData = null;
		sourceSize = null;
		paddedSize = null;
		atlas = null;
		key = -1;
	}
}