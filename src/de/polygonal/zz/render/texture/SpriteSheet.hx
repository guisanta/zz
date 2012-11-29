/*
 *                            _/                                                    _/
 *       _/_/_/      _/_/    _/  _/    _/    _/_/_/    _/_/    _/_/_/      _/_/_/  _/
 *      _/    _/  _/    _/  _/  _/    _/  _/    _/  _/    _/  _/    _/  _/    _/  _/
 *     _/    _/  _/    _/  _/  _/    _/  _/    _/  _/    _/  _/    _/  _/    _/  _/
 *    _/_/_/      _/_/    _/    _/_/_/    _/_/_/    _/_/    _/    _/    _/_/_/  _/
 *   _/                            _/        _/
 *  _/                        _/_/      _/_/
 *
 * POLYGONAL - A HAXE LIBRARY FOR GAME DEVELOPERS
 * Copyright (c) 2009 Michael Baczynski, http://www.polygonal.de
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
package de.polygonal.zz.render.texture;

import de.polygonal.ds.DA;

class SpriteSheet
{
	public var tex(default, null):Tex;
	
	public var frameCount(default, null):Int;
	
	var _cropList:DA<Rect>;
	var _sizeList:DA<Size>;
	
	var _sheetW:Int;
	var _sheetH:Int;
	
	public var __spriteStrip:SpriteStrip;
	public var __spriteAtlas:SpriteAtlas;
	
	function new(tex:Tex, frameCount:Int)
	{
		this.tex = tex;
		this.frameCount = frameCount;
		
		_sheetW = tex.image.w;
		_sheetH = tex.image.h;
		
		__spriteStrip = null;
		__spriteAtlas = null;
		
		_cropList = new DA(frameCount, frameCount);
		_cropList.fill(null, frameCount);
		_sizeList = new DA(frameCount, frameCount);
		_sizeList.fill(null, frameCount);
	}
	
	public function free():Void
	{
		tex = null;
		
		__spriteStrip = null;
		__spriteAtlas = null;
		_cropList.free();
		_cropList = null;
		_sizeList.free();
		_sizeList = null;
	}
	
	inline public function getSize(index:Int):Size
	{
		return _sizeList.get(index);
	}
	
	inline public function getCropRect(index:Int):Rect
	{
		return _cropList.get(index);
	}
	
	function addCropRectAt(index:Int, crop:Rect, normalize:Bool, pack:Bool)
	{
		crop = crop.clone();
		
		_cropList.set(index, crop);
		_sizeList.set(index, new Size(Std.int(crop.w), Std.int(crop.h)));
		
		if (pack)
		{
			crop.x += .5;
			crop.y += .5;
			crop.w -= 1.;
			crop.h -= 1.;
		}
		
		if (normalize)
		{
			crop.x /= tex.w;
			crop.y /= tex.h;
			crop.w /= tex.w;
			crop.h /= tex.h;
		}
		
		crop.r = crop.x + crop.w;
		crop.b = crop.y + crop.h;
	}
}