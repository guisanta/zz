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
import de.polygonal.core.math.Rect.Rectf;
import de.polygonal.core.math.Rect.Recti;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.ds.StringHashTable;
import de.polygonal.ds.Vector;
import de.polygonal.zz.data.Size.Sizei;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat.TextureAtlasDef;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat.TextureAtlasFrameDef;
import de.polygonal.core.math.Mathematics;

class TextureAtlas
{
	public var numFrames(default, null):Int;
	public var scale(default, null):Float;
	public var texture(default, null):Texture;
	public var userData(default, null):Dynamic;
	
	var mFramesByIndex:Vector<TextureAtlasFrame>;
	var mFramesByName:StringHashTable<TextureAtlasFrame>;
	
	public function new(texture:Texture, data:TextureAtlasDef)
	{
		this.texture = texture;
		
		userData = data.userData;
		
		scale = data.scale;
		
		mFramesByName = new StringHashTable();
		
		var max = 0;
		for (i in data.frames) max = M.max(max, i.index);
		
		mFramesByIndex = new Vector<TextureAtlasFrame>(max + 1);
		
		numFrames = 0;
		for (i in data.frames)
		{
			var frame = i == null ? null : new TextureAtlasFrame(this, i);
			mFramesByIndex[frame.index] = frame;
			mFramesByName.set(i.name, frame);
			numFrames++;
		}
	}
	
	/*public function addSubTextureAtlas(format:TextureAtlasFormat, frame:TextureFrame)
	{
		//TODO adjust coordinates..
		trace('adjust coordinates');
		
		for (i in 0...format.data.frames.length)
		{
			var f = format.data.frames[i];
			
			//mFramesByIndex[frame.index] = frame;
			//mFramesByName.set(i.name, frame);
			
			//shift cropRectangle
			
			//var subFrame = data.getFrameAtIndex(i);
		}
	}*/
	
	inline public function getFrameAt(index:Int):TextureAtlasFrame
	{
		assert(index >= 0 && index < mFramesByIndex.length);
		return mFramesByIndex[index];
	}
	
	inline public function getFrameBy(name:String):TextureAtlasFrame
	{
		#if debug
		var f = mFramesByName.get(name);
		assert(f != null, 'frame "$name" not found');
		return f;
		#else
		return mFramesByName.get(name);
		#end
	}
}

class TextureAtlasFrame
{
	public var index(default, null):Int;
	
	public var name(default, null):String;
	
	public var trimmed(default, null):Bool;
	
	public var trimOffset(default, null):Coord2i;
	
	/**
		The original size *before* trimming.
	**/
	public var untrimmedSize(default, null):Sizei;
	
	public var texCoordUv(default, null):Rectf;
	public var texCoordPx(default, null):Recti;
	
	public function new(atlas:TextureAtlas, data:TextureAtlasFrameDef)
	{
		index = data.index;
		name = data.name;
		
		var texture = atlas.texture;
		var s = texture.sourceSize;
		var r = data.cropRect;
		
		var uv = texCoordUv = new Rectf(r.x, r.y, r.w, r.h);
		uv.x /= s.x;
		uv.y /= s.y;
		uv.w /= s.x;
		uv.h /= s.y;
		
		if (texture.isPadded)
		{
			var sX = s.x / texture.paddedSize.x;
			var sY = s.y / texture.paddedSize.y;
			uv.x *= sX;
			uv.y *= sY;
			uv.w *= sX;
			uv.h *= sY;
		}
		
		texCoordPx = data.cropRect.clone();
		
		trimmed = data.trimFlag;
		if (trimmed)
		{
			trimOffset = data.trimOffset.clone();
			untrimmedSize = data.untrimmedSize.clone();
		}
		else
		{
			trimOffset = new Coord2i();
			untrimmedSize = new Sizei(data.cropRect.w, data.cropRect.h);
		}
	}
}