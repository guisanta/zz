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
package de.polygonal.zz.texture.atlas;

import de.polygonal.core.math.Coord2.Coord2i;
import de.polygonal.core.math.Recti;
import de.polygonal.zz.data.Size.Sizei;

@:publicFields
class TextureAtlasFrameDef
{
	var index:Int;
	var name:String;
	var cropRect = new Recti();
	var trimFlag = false;
	var sourceSize = new Sizei();
	var trimOffset = new Coord2i();
	
	function new() {}
}

@:publicFields
class TextureAtlasDef
{
	var size = new Sizei();
	var scale = 1.;
	var frames = new Array<TextureAtlasFrameDef>();
	var userData:Dynamic = null;
	
	function new() {}
}

interface TextureAtlasFormat
{
	function getAtlas():TextureAtlasDef;
}