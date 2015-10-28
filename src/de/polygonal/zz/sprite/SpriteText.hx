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
package de.polygonal.zz.sprite;

import de.polygonal.core.fmt.Ascii;
import de.polygonal.core.math.Aabb2;
import de.polygonal.core.math.Mathematics.M;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.ds.Vector;
import de.polygonal.zz.render.effect.TextureEffect;
import de.polygonal.zz.scene.CullingMode;
import de.polygonal.zz.scene.Node;
import de.polygonal.zz.scene.Quad;
import de.polygonal.zz.scene.Spatial;
import de.polygonal.zz.texture.atlas.format.BmFontFormat.BitmapChar;
import de.polygonal.zz.texture.atlas.format.BmFontFormat.BitmapCharSet;
import de.polygonal.zz.texture.atlas.TextureAtlas;
import de.polygonal.zz.texture.Texture;
import de.polygonal.zz.texture.TextureLib;

@:enum
abstract TextAlign(Int)
{
	var Left = 1;
	var Center = 2;
	var Right = 3;
}

@:allow(de.polygonal.zz.sprite.SpriteText)
class SpriteTextSettings
{
	var mText = null;
	var mAlign = TextAlign.Left;
	var mMultiline = true;
	var mKerning = true;
	var mSize = 12;
	var mWidth = 100.;
	var mHeight = 100.;
	var mTracking = 0.;
	var mLeading = 0.;
	
	var mChanged = true;
	
	function new()
	{
	}
	
	public var text(get_text, set_text):String;
	inline function get_text():String return mText;
	function set_text(value:String):String
	{
		assert(value != null);
		mChanged = mChanged || (mText != value);
		return mText = value;
	}
	
	public var size(get_size, set_size):Int;
	inline function get_size():Int return mSize;
	function set_size(value:Int):Int
	{
		mChanged = mChanged || (mSize != value);
		return mSize = value;
	}
	
	public var width(get_width, set_width):Float;
	inline function get_width():Float return mWidth;
	function set_width(value:Float):Float
	{
		mChanged = mChanged || (mWidth != value);
		mChanged = true;
		return mWidth = value;
	}
	
	public var height(get_height, set_height):Float;
	inline function get_height():Float return mHeight;
	function set_height(value:Float):Float
	{
		mChanged = mChanged || (mHeight != value);
		return mHeight = value;
	}
	
	public var align(get_align, set_align):TextAlign;
	inline function get_align():TextAlign return mAlign;
	function set_align(value:TextAlign):TextAlign
	{
		mChanged = mChanged || (mAlign != value);
		return mAlign = value;
	}
	
	public var multiline(get_multiline, set_multiline):Bool;
	inline function get_multiline():Bool return mMultiline;
	function set_multiline(value:Bool):Bool
	{
		mChanged = mChanged || (mMultiline != value);
		return mMultiline = value;
	}
	
	public var kerning(get_kerning, set_kerning):Bool;
	inline function get_kerning():Bool return mKerning;
	function set_kerning(value:Bool):Bool
	{
		mChanged = mChanged || (mKerning != value);
		return mKerning = value;
	}
	
	public var tracking(get_tracking, set_tracking):Float;
	inline function get_tracking():Float return mTracking;
	function set_tracking(value:Float):Float
	{
		mChanged = mChanged || (mTracking != value);
		return mTracking = value;
	}
	
	public var leading(get_leading, set_leading):Float;
	inline function get_leading():Float return mLeading;
	function set_leading(value:Float):Float
	{
		mChanged = mChanged || (mLeading != value);
		return mLeading = value;
	}
}

@:access(de.polygonal.zz.scene.Spatial)
class SpriteText extends SpriteBase
{
	public var settings(default, null) = new SpriteTextSettings();
	public var overflow(default, null):Bool;
	
	public var bounds(default, null) = new Aabb2(0, 0, 0, 0);
	
	var mNode:Node;
	var mTexture:Texture;
	var mAtlas:TextureAtlas;
	var mShaper:Shaper;
	
	var mTextureChanged:Bool;
	
	public function new(?parent:SpriteGroup, ?textureId:Null<Int>)
	{
		var spatial = new Node();
		super(spatial);
		
		mSpatial.mFlags &= ~Spatial.IS_COMPOSITE_LOCKED;
		spatial.arbiter = this;
		mSpatial.mFlags |= Spatial.IS_COMPOSITE_LOCKED;
		
		mNode = cast mSpatial;
		
		mShaper = new Shaper();
		
		if (parent != null) parent.addChild(this);
		if (textureId != null) setTexture(textureId);
	}
	
	override public function free()
	{
		if (mNode == null) return;
		
		var c = mNode.child;
		while (c != null)
		{
			var next = c.mSibling;
			c.free();
			c = next;
		}
		super.free();
		
		mNode = null;
		mAtlas = null;
		bounds = null;
	}
	
	public function setTexture(textureId:Int)
	{
		mTexture = TextureLib.getTexture(textureId);
		mTextureChanged = true;
		mAtlas = mTexture.atlas;
		
		if (settings.size == 0)
			settings.size = cast(mAtlas.userData, BitmapCharSet).renderedSize;
	}
	
	public function autoFit(minSize:Int, maxSize:Int)
	{
		overflow = mShaper.shape(mAtlas.userData, settings);
		
		var currentSize = settings.size, bestSize;
		
		if (overflow)
		{
			if (currentSize < minSize) return;
			
			bestSize = bsearch(minSize, currentSize - 1);
		}
		else
		{
			if (currentSize > maxSize) return;
			
			bestSize = bsearch(currentSize, maxSize + 1);
		}
		
		settings.size = bestSize;
		overflow = mShaper.shape(mAtlas.userData, settings);
	}
	
	public function shrinkToFit(minSize:Int)
	{
		overflow = mShaper.shape(mAtlas.userData, settings);
		
		if (!overflow) return;
		
		var currentSize = settings.size;
		if (currentSize < minSize) return;
		
		settings.size = bsearch(minSize, currentSize - 1);
		overflow = mShaper.shape(mAtlas.userData, settings);
	}
	
	public function growToFit(maxSize:Int)
	{
		overflow = mShaper.shape(mAtlas.userData, settings);
		
		if (overflow) return;
		
		var currentSize = settings.size;
		if (currentSize > maxSize) return;
		
		settings.size = bsearch(currentSize, maxSize + 1);
		overflow = mShaper.shape(mAtlas.userData, settings);
	}
	
	function bsearch(lo:Int, hi:Int):Int
	{
		var l = lo, h = hi, s = -1;
		var m = l + ((h - l) >> 1);
		while (true)
		{
			settings.size = m;
			if (mShaper.shape(mAtlas.userData, settings))
			{
				//decrease size
				h = m;
				m = l + ((h - l) >> 1);
				if (m == l) break;
			}
			else
			{
				//increase size
				s = m;
				l = m;
				m = l + ((h - l) >> 1);
				if (m == l) break;
			}
		}
		
		if (s < 0) return lo;
		
		return s;
	}
	
	override function get_width():Float
	{
		commit();
		return bounds.w * M.fabs(scaleX);
	}
	
	override function get_height():Float
	{
		commit();
		return bounds.h * M.fabs(scaleY);
	}
	
	override public function centerPivot()
	{
		commit();
		mPivotX = bounds.x + bounds.w / 2;
		mPivotY = bounds.y + bounds.h / 2;
		setDirty();
		super.commit();
	}
	
	override public function tick(timeDelta:Float)
	{
		//remove culled glyphs after an idle time of 10 seconds
		var child = mNode.child;
		var g:Glyph;
		while (child != null)
		{
			if (child.mFlags & Spatial.CULL_ALWAYS > 0)
			{
				g = cast child;
				
				g.idleTime += timeDelta;
				if (g.idleTime > 10)
				{
					var next = child.mSibling;
					mNode.removeChild(child);
					child.free();
					child = next;
					continue;
				}
			}
			child = child.mSibling;
		}
		
		super.tick(timeDelta);
	}
	
	override public function commit():SpriteBase
	{
		if (getDirty()) super.commit();
		
		clrDirty();
		
		if (mTexture == null) return this;
		
		if (settings.text == null) return this;
		
		if (!settings.mChanged && !mTextureChanged) return this;
		
		if (mTextureChanged)
		{
			mTextureChanged = false;
			
			var c = mNode.child, next;
			while (c != null)
			{
				next = c.mSibling;
				mNode.removeChild(c);
				c.free();
				c = next;
			}
		}
		
		settings.mChanged = false;
		
		overflow = mShaper.shape(mAtlas.userData, settings);
		
		var minX = M.POSITIVE_INFINITY;
		var minY = M.POSITIVE_INFINITY;
		var maxX = M.NEGATIVE_INFINITY;
		var maxY = M.NEGATIVE_INFINITY;
		
		//cull existing quads
		var numExisting = 0;
		var c = mNode.child;
		while (c != null)
		{
			numExisting++;
			c.cullingMode = CullingMode.CullAlways;
			c = c.mSibling;
		}
		c = mNode.child;
		
		var data = mShaper.data;
		var i = 0;
		var j = 0;
		var code, x, y, w, h;
		var g, e;
		while (i++ < mShaper.numChars)
		{
			code = Std.int(data[j++]);
			if (code == Ascii.SPACE) //don't draw whitespace characters
			{
				j += 4;
				continue;
			}
			
			x = data[j++];
			y = data[j++];
			w = data[j++];
			h = data[j++];
			
			if (numExisting > 0)
			{
				//reuse existing visual
				g =
				#if flash
				flash.Lib.as(c, Glyph);
				#else
				cast(c, Glyph);
				#end
				
				c = c.mSibling;
				numExisting--;
				
				g.name = String.fromCharCode(code);
				g.cullingMode = CullingMode.CullDynamic;
			}
			else
			{
				//create new visual
				g = new Glyph(String.fromCharCode(code));
				e = new TextureEffect();
				e.setTexture(mTexture, mAtlas);
				g.effect = e;
				
				mNode.addChildAt(g, 0); //draw in reverse order
			}
			
			//set position and frame
			g.local.setTranslate2(x, y);
			g.local.setScale2(w, h);
			g.mFlags |= Spatial.IS_WORLD_XFORM_DIRTY; //enforce updateGeometricState()
			g.effect.as(TextureEffect).setFrameIndex(code);
			
			minX = M.fmin(minX, x);
			minY = M.fmin(minY, y);
			maxX = M.fmax(maxX, x + w);
			maxY = M.fmax(maxY, y + h);
		}
		
		bounds.set(minX, minY, maxX, maxY);
		
		//reset idle time on unused visuals
		while (numExisting > 0)
		{
			g = cast c;
			g.idleTime = 0;
			c = c.mSibling;
			numExisting--;
		}
		assert(c == null);
		
		//only keep 100 inactive glyphs alive
		var inactiveCount = 0, c = mNode.child, next;
		while (c != null)
		{
			if (c.mFlags & Spatial.CULL_ALWAYS > 0)
			{
				if (++inactiveCount == 100)
					break;
			}
			c = c.mSibling;
		}
		while (c != null)
		{
			next = c.mSibling;
			mNode.removeChild(c);
			c.free();
			c = next;
		}
		
		return this;
	}
	
	public function getOutputText():String //TODO includes whitespace?
	{
		var s = "";
		for (i in 0...mShaper.numChars)
			s += String.fromCharCode(Std.int(mShaper.data[i * 5]));
		return s;
	}
}

private class Glyph extends Quad
{
	public var idleTime = 0.;
	
	public function new(name:String)
	{
		super(name);
	}
}

private class Shaper
{
	public var data = new Array<Float>();
	public var numChars = 0;
	
	var mCharCodes = new Vector<Int>(4096);
	
	public function new()
	{
	}
	
	public function shape(charSet:BitmapCharSet, settings:SpriteTextSettings):Bool
	{
		numChars = 0;
		
		var str = settings.text;
		
		var numInputChars = str.length;
		for (i in 0...numInputChars)
			mCharCodes.set(i, str.charCodeAt(i));
		
		var boxW     = settings.width;
		var boxH     = settings.height;
		var kerning  = settings.kerning;
		var tracking = settings.tracking;
		var align    = settings.align;
		
		var bmpCharLut = charSet.characters;
		var kerningLut = charSet.kerning;
		
		var scale = settings.size / charSet.renderedSize;
		var stepY = (charSet.lineHeight + settings.leading) * scale;
		var numLines = Std.int(boxH / stepY);
		if (numLines == 0) return true;
		if (!settings.multiline) numLines = 1;
		
		var codes = mCharCodes, code, lastCode = 0;
		var kerningAmount = 0;
		var newline = true;
		
		var cursorX = 0.;
		var cursorY = 0.;
		var line = 0;
		var next = 0;
		var firstCharInLineIndex = 0;
		var lastCharInLineIndex = 0;
		
		#if debug
		var iter = 0;
		var maxIter = 100;
		#end
		
		var numSpaceChars = 0;
		
		var charCountCurrent;
		var charCountSegment;
		var x, y;
		var segmentMinX, segmentMaxX;
		var bc;
		
		inline function isWhiteSpace(x:Int) return x == Ascii.NEWLINE || x == Ascii.SPACE;
		
		inline function getKerning(first:Int, second:Int):Int return kerningLut.hasKey(second << 16 | first) ? kerningLut.get(second << 16 | first) : 0;
		
		inline function nextLine()
		{
			newline = true;
			cursorX = 0.;
			cursorY += stepY;
		}
		
		inline function output(code:Int, bc:BitmapChar)
		{
			data[next++] = code;
			data[next++] = cursorX + bc.offsetX * scale;
			data[next++] = cursorY + bc.offsetY * scale;
			data[next++] = bc.w * scale;
			data[next++] = bc.h * scale;
			numChars++;
		}
		
		function alignLine(minI:Int, maxI:Int)
		{
			if (minI == maxI) return;
			
			if (align == TextAlign.Left) return;
			
			var lineMinX = boxW;
			var lineMaxX = 0.;
			var ii = firstCharInLineIndex;
			while (ii < lastCharInLineIndex)
			{
				var c = Std.int(data[ii]);
				
				if (c == 32)
				{
					ii += 5;
					continue;
				}
				
				var t = data[ii + 1];
				if (t < lineMinX) lineMinX = t;
				
				var t = data[ii + 1] + data[ii + 3];
				if (t > lineMaxX) lineMaxX = t;
				
				ii += 5;
			}
			
			var offset = boxW - lineMaxX;
			
			if (align == TextAlign.Right)
			{
				ii = firstCharInLineIndex;
				while (ii < lastCharInLineIndex)
				{
					var t = data[ii + 1];
					t += offset;
					data[ii + 1] = t;
					
					ii += 5;
				}
			}
			else
			if (align == TextAlign.Center)
			{
				offset /= 2;
				
				ii = firstCharInLineIndex;
				while (ii < lastCharInLineIndex)
				{
					var t = data[ii + 1];
					t += offset;
					data[ii + 1] = t;
					
					ii += 5;
				}
			}
		}
		
		var i = 0, k = numInputChars, j;
		while (i < k)
		{
			#if debug
			if (iter++ == maxIter) throw "bail out!";
			#end
			
			if (newline)
			{
				line++;
				if (line > numLines) return true;
				//trace('line from $firstCharInLineIndex ... $lastCharInLineIndex');
				
				if (align != TextAlign.Left)
					alignLine(firstCharInLineIndex, lastCharInLineIndex);
				
				firstCharInLineIndex = lastCharInLineIndex;
				lastCharInLineIndex = firstCharInLineIndex;
				
				newline = false;
				lastCode = 0;
				
				bc = bmpCharLut[codes[i]];
				if (bc.offsetX < 0) cursorX = -bc.offsetX;
			}
			
			//get segment length in #characters
			charCountSegment = 0;
			j = i;
			while (j < k)
			{
				code = codes[j++];
				if (isWhiteSpace(code)) break;
				charCountSegment++;
			}
			
			//scan forward, test if the segment fits into the current line
			j = i;
			charCountCurrent = 0;
			x = cursorX;
			y = cursorY;
			code = codes[j];
			bc = bmpCharLut[code];
			
			segmentMinX = (x + (bc.offsetX * scale));
			segmentMaxX = 0.;
			
			while (j < i + charCountSegment)
			{
				code = codes[j++];
				bc = bmpCharLut[code];
				
				segmentMaxX = (x + (bc.offsetX * scale)) + (bc.w * scale);
				
				if (kerning)
				{
					kerningAmount = getKerning(lastCode, code);
					segmentMaxX += kerningAmount * scale;
					lastCode = code;
				}
				
				if (segmentMaxX > boxW) break; //horizontal overflow?
				
				charCountCurrent++;
				
				//advance cursor
				x += bc.advanceX * scale + tracking;
				if (kerning) x += kerningAmount * scale;
			}
			
			if (charCountCurrent < charCountSegment) //wrap segment?
			{
				if ((segmentMaxX - segmentMinX) > boxW) return true; //segment will never fit, quit
				nextLine();
				continue;
			}
			else
			{
				//entire segment fits into the current line
				j = i + charCountCurrent;
				while (i < j)
				{
					code = codes[i++];
					bc = bmpCharLut[code];
					
					if (kerning)
					{
						kerningAmount = getKerning(lastCode, code);
						lastCode = code;
						cursorX += kerningAmount * scale;
					}
					
					assert(code > Ascii.SPACE);
					output(code, bc);
					lastCharInLineIndex = next;
					cursorX += bc.advanceX * scale + tracking;
				}
				
				lastCode = code;
				code = codes[i]; //first whitespace character
				
				//var spaceCount = 0;
				//numSpaceChars = 0;
				
				while (isWhiteSpace(code))
				{
					bc = bmpCharLut[code];
					
					if (code == Ascii.NEWLINE)
					{
						nextLine();
					}
					else
					if (code == Ascii.SPACE)
					{
						if (kerning)
						{
							kerningAmount = getKerning(lastCode, code);
							cursorX += kerningAmount * scale;
						}
						cursorX += bc.advanceX * scale + tracking;
						
						if (cursorX > boxW) //horizontal overflow?
						{
							//trim trailing spaces before breaking the line
							while (i + 1 < k && codes[i + 1] == Ascii.SPACE) i++;
							//numSpaceChars = 0;
							nextLine();
						}
						
						//numSpaceChars++;
					}
					
					lastCode = code;
					code = codes[++i];
				}
				
				if (!newline)
				{
					bc = bmpCharLut[code];
					//for (i in 0...spaceCount) output(Ascii.SPACE, bc);
				}
			}
		}
		
		if (align != TextAlign.Left)
			alignLine(firstCharInLineIndex, lastCharInLineIndex);
		
		return false;
	}
}