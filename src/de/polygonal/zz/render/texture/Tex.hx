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

import de.polygonal.core.math.Mathematics;
import de.polygonal.ds.HashableItem;

class Tex extends HashableItem
{
	public var image(default, null):Image;
	
	public var isPowerOfTwo(default, null):Bool = true;
	
	/**
	 * If true, UV coordinates are normalized to [0,1].
	 */
	public var isNormalize(default, null):Bool = true;
	public var isPack(default, null):Bool = false;
	
	/**
	 * The width of the texture in pixels.<br/>
	 * If <em>powerOfTwo</em> is true, <code>w</code> is a power of two.
	 */
	public var w:Int;
	
	/**
	 * The height of the texture in pixels.<br/>
	 * If <em>powerOfTwo</em> is true, <code>h</code> is a power of two.
	 */
	public var h:Int;
	
	public function new(image:Image, powerOfTwo:Bool, normalize:Bool)
	{
		super();
		
		this.image = image;
		isPowerOfTwo = powerOfTwo;
		isNormalize = normalize;
		if (powerOfTwo)
		{
			w = M.nextPow2(image.w);
			h = M.nextPow2(image.h);
		}
		else
		{
			w = image.w;
			h = image.h;
		}
	}
	
	public function free()
	{
		if (image != null)
		{
			trace('FREE TEXTURE ' + image.key);
			image.free();
			image = null;
		}
	}
}