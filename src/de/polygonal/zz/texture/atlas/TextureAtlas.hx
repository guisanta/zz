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
import de.polygonal.core.math.Mathematics;
import de.polygonal.core.math.Rectf;
import de.polygonal.core.math.Recti;
import de.polygonal.ds.ArrayList;
import de.polygonal.ds.IntHashTable;
import de.polygonal.zz.data.Size.Sizei;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat.TextureAtlasDef;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat.TextureAtlasFrameDef;
import haxe.ds.StringMap;

class TextureAtlas
{
	public var numFrames(default, null):Int;
	public var scale(default, null):Float;
	public var texture(default, null):Texture;
	public var userData(default, null):Dynamic;
	
	var mFrameLut:ArrayList<TextureAtlasFrame>;
	var mFrameMap:IntHashTable<TextureAtlasFrame>;
	var mFrameByName:StringMap<TextureAtlasFrame>;
	var mDense:Bool;
	
	public function new(texture:Texture, data:TextureAtlasDef)
	{
		this.texture = texture;
		
		scale = data.scale;
		userData = data.userData;
		numFrames = data.frames.length;
		
		mFrameByName = new StringMap();
		
		var ids = new ArrayList<Int>(numFrames);
		var maxId = 0;
		for (i in data.frames)
		{
			ids.add(i.id);
			maxId = Mathematics.max(maxId, i.id);
		}
		
		mDense = true;
		
		ids.sort(function(a, b) return a - b, true);
		var c = ids.get(0);
		if (c != 0)
			mDense = false;
		else
		{
			for (i in 1...numFrames)
			{
				if (c + 1 != ids.get(i))
				{
					mDense = false;
					break;
				}
				c++;
			}
		}
		
		if (mDense)
		{
			mDense = true;
			mFrameLut = new ArrayList<TextureAtlasFrame>().init(maxId + 1, null);
			for (def in data.frames)
			{
				assert(def != null);
				var frame = new TextureAtlasFrame(this, def);
				mFrameLut.set(frame.id, frame);
				mFrameByName.set(def.name, frame);
			}
		}
		else
		{
			mDense = false;
			mFrameMap = new IntHashTable<TextureAtlasFrame>(Mathematics.nextPow2(numFrames));
			for (def in data.frames)
			{
				assert(def != null);
				var frame = new TextureAtlasFrame(this, def);
				mFrameMap.set(frame.id, frame);
				mFrameByName.set(def.name, frame);
			}
		}
		
		#if debug
		for (frame in getFrames()) assert(frame != null);
		#end
	}
	
	public function getFrames():Array<TextureAtlasFrame>
	{
		return
		if (mDense)
			mFrameLut.toArray();
		else
			[for (key in mFrameMap.keys()) mFrameMap.get(key)];
	}
	
	inline public function getFrameById(id:Int):TextureAtlasFrame
	{
		return mDense ? mFrameLut.get(id) : mFrameMap.get(id);
	}
	
	inline public function getFrameByName(name:String):TextureAtlasFrame
	{
		#if debug
		var f = mFrameByName.get(name);
		assert(f != null, 'frame "$name" not found');
		return f;
		#else
		return mFrameByName.get(name);
		#end
	}
}

class TextureAtlasFrame
{
	public var id(default, null):Int;
	
	public var name(default, null):String;
	
	public var trimmed(default, null):Bool;
	
	public var trimOffset(default, null):Coord2i;
	
	/**
		The original size *before* trimming.
	**/
	public var sourceSize(default, null):Sizei;
	
	public var texCoordUv(default, null):Rectf;
	public var texCoordPx(default, null):Recti;
	
	public function new(atlas:TextureAtlas, data:TextureAtlasFrameDef)
	{
		id = data.id;
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
			sourceSize = data.sourceSize.clone();
		}
		else
		{
			trimOffset = new Coord2i();
			sourceSize = new Sizei(data.cropRect.w, data.cropRect.h);
		}
	}
}