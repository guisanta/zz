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
import de.polygonal.core.util.Assert.assert;
import de.polygonal.ds.Vector;
import de.polygonal.zz.data.Size.Sizef;
import de.polygonal.zz.render.effect.TextureEffect;
import de.polygonal.zz.scene.CullingMode;
import de.polygonal.zz.scene.Node;
import de.polygonal.zz.scene.Quad;
import de.polygonal.zz.scene.Spatial;
import de.polygonal.zz.scene.Spatial.as;
import de.polygonal.zz.texture.atlas.format.BmFontFormat.BitmapChar;
import de.polygonal.zz.texture.atlas.format.BmFontFormat.BitmapCharSet;
import de.polygonal.zz.texture.atlas.TextureAtlas;
import de.polygonal.zz.texture.Texture;
import de.polygonal.zz.texture.TextureLib;
import de.polygonal.core.math.Mathematics;
import de.polygonal.zz.sprite.SpriteBase.*;

enum TextAlign { Left; Center; Right; }

typedef SpriteTextProperties =
{
	text:String, size:Int, align:TextAlign, width:Float, height:Float,
	kerning:Bool, multiline:Bool, tracking:Float, leading:Float
}

@:access(de.polygonal.zz.scene.Spatial)
class SpriteText extends SpriteBase
{
	inline public static var TYPE = 3;
	
	/**
		True if the entire text does not fit.
	**/
	public var isOverflowing(default, null):Bool;
	
	var mNode:Node;
	var mTexture:Texture;
	var mAtlas:TextureAtlas;
	var mShaper:Shaper;
	var mTextureChanged:Bool;
	var mHasSleepingQuads:Bool;
	var mChanged = true;
	var mProperties:SpriteTextProperties =
	{
		text: "", size: 10, align: TextAlign.Left, width: 100., height: 100.,
		kerning: true, multiline: true, tracking: 0., leading: 0.
	}
	
	public function new(?parent:SpriteGroup, ?textureId:Null<Int>)
	{
		var spatial = new Node("SpriteText");
		
		super(spatial);
		
		type = TYPE;
		
		mNode = cast mSpatial;
		mNode.mFlags &= ~Spatial.IS_NODE;
		mNode.mFlags |= Spatial.IS_VISUAL; //treat as leaf
		
		mShaper = new Shaper();
		
		if (parent != null) parent.addChild(this);
		if (textureId != null)
		{
			setTexture(textureId);
			mProperties.size = cast(mAtlas.userData, BitmapCharSet).renderedSize;
		}
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
		mTexture = null;
		mAtlas = null;
		mProperties = null;
	}
	
	public function getText(?raw = false):String
	{
		return mProperties.text;
	}
	public function setText(value:Dynamic):SpriteText
	{
		mChanged = mChanged || (mProperties.text != Std.string(value));
		mProperties.text = Std.string(value);
		return this;
	}
	
	public function getFontSize():Int
	{
		return mProperties.size;
	}
	public function setFontSize(value:Int):SpriteText
	{
		mChanged = mChanged || (mProperties.size != value);
		mProperties.size = value;
		return this;
	}
	
	public function getTextBox():Sizef
	{
		return new Sizef(mProperties.width, mProperties.height);
	}
	public function setTextBox(width:Float, height:Float):SpriteText
	{
		mChanged = mChanged || (mProperties.width != width);
		mChanged = mChanged || (mProperties.height != height);
		mProperties.width = width;
		mProperties.height = height;
		return this;
	}
	
	public function getAlign():TextAlign
	{
		return mProperties.align;
	}
	public function setAlign(value:TextAlign):SpriteText
	{
		mChanged = mChanged || (mProperties.align != value);
		mProperties.align = value;
		return this;
	}
	
	public function getMultiline():Bool
	{
		return mProperties.multiline;
	}
	public function setMultiline(value:Bool):SpriteText
	{
		mChanged = mChanged || (mProperties.multiline != value);
		mProperties.multiline = value;
		return this;
	}
	
	public function getKerning():Bool
	{
		return mProperties.kerning;
	}
	public function setKerning(value:Bool):SpriteText
	{
		mChanged = mChanged || (mProperties.kerning != value);
		mProperties.kerning = value;
		return this;
	}
	
	public function getLeading():Float
	{
		return mProperties.leading;
	}
	public function setLeading(value:Float):SpriteText
	{
		mChanged = mChanged || (mProperties.leading != value);
		mProperties.leading = value;
		return this;
	}
	
	public function getTracking():Float
	{
		return mProperties.tracking;
	}
	public function setTracking(value:Float):SpriteText
	{
		mChanged = mChanged || (mProperties.tracking != value);
		mProperties.tracking = value;
		return this;
	}
	
	public function setTexture(textureId:Int)
	{
		mTexture = TextureLib.getTexture(textureId);
		mTextureChanged = true;
		mAtlas = mTexture.atlas;
	}
	
	public function setToRenderedSize()
	{
		var size = cast(mAtlas.userData, BitmapCharSet).renderedSize;
		mChanged = mChanged || (mProperties.size != size);
		mProperties.size = size;
	}
	
	public function autoFit(minSize:Int, maxSize:Int)
	{
		mProperties.size = (maxSize - minSize) >> 1;
		
		isOverflowing = mShaper.shape(mAtlas.userData, mProperties);
		
		var currentSize = mProperties.size, bestSize;
		
		if (isOverflowing)
		{
			if (currentSize < minSize) return;
			
			bestSize = bsearch(minSize, currentSize - 1);
		}
		else
		{
			if (currentSize > maxSize) return;
			
			bestSize = bsearch(currentSize, maxSize + 1);
		}
		
		bestSize = M.clamp(bestSize, minSize, maxSize);
		
		mProperties.size = bestSize;
		mChanged = true;
		isOverflowing = mShaper.shape(mAtlas.userData, mProperties);
	}
	
	public function shrinkToFit(minSize:Int)
	{
		isOverflowing = mShaper.shape(mAtlas.userData, mProperties);
		
		if (!isOverflowing) return;
		
		var currentSize = mProperties.size;
		if (currentSize < minSize) return;
		
		mProperties.size = bsearch(minSize, currentSize - 1);
		mChanged = true;
		isOverflowing = mShaper.shape(mAtlas.userData, mProperties);
	}
	
	public function growToFit(maxSize:Int)
	{
		isOverflowing = mShaper.shape(mAtlas.userData, mProperties);
		
		if (isOverflowing) return;
		
		var currentSize = mProperties.size;
		if (currentSize > maxSize) return;
		
		mProperties.size = bsearch(currentSize, maxSize + 1);
		mChanged = true;
		isOverflowing = mShaper.shape(mAtlas.userData, mProperties);
	}
	
	public function align9(bounds:Aabb2, horizontal:Int, vertical:Int, baseline = true)
	{
		var charBounds = baseline ? mShaper.looseBounds : mShaper.tightBounds;
		
		x =
		if (horizontal < 0)
			bounds.minX;
		else
		if (horizontal > 0)
			bounds.maxX - charBounds.w;
		else
			bounds.cx - (charBounds.w / 2);
		
		y =
		if (vertical < 0)
			bounds.minY;
		else
		if (vertical > 0)
			bounds.maxY - charBounds.h;
		else
			bounds.cy - (charBounds.h / 2);
		
		x -= charBounds.minX;
		y -= charBounds.minY;
	}
	
	public function getCharBounds(tight = true):Aabb2
	{
		return tight ? mShaper.tightBounds.clone() : mShaper.looseBounds.clone();
	}
	
	override public function getBounds(targetSpace:SpriteBase, ?output:Aabb2, ?trim:Bool = false):Aabb2
	{
		if (mFlags & IS_LOCAL_DIRTY > 0) syncLocal();
		
		if (targetSpace == null) targetSpace = this;
		if (output == null) output = new Aabb2();
		
		return mSpatial.getBoundingBox(targetSpace.sgn, output);
	}
	
	override public function centerPivot()
	{
		var charBounds = getCharBounds(true);
		mPivotX = charBounds.cx;
		mPivotY = charBounds.cy;
		mFlags |= IS_LOCAL_DIRTY;
	}
	
	override public function tick(timeDelta:Float)
	{
		super.tick(timeDelta);
		
		//remove culled glyphs after x seconds
		if (!mHasSleepingQuads) return;
		
		var numSleeping = 0;
		var c = mNode.child, g;
		while (c != null)
		{
			if (c.mFlags & Spatial.CULL_ALWAYS > 0)
			{
				g = as(c, Glyph);
				g.idleTime += timeDelta;
				if (g.idleTime > 10)
				{
					var next = c.mSibling;
					mNode.removeChild(c);
					c.free();
					c = next;
					continue;
				}
				else
					numSleeping++;
			}
			c = c.mSibling;
		}
		
		mHasSleepingQuads = numSleeping > 0;
	}
	
	override public function syncLocal():SpriteBase
	{
		super.syncLocal();
		
		if (mTexture == null) return this;
		if (mProperties.text == null) return this;
		if (!mChanged && !mTextureChanged) return this;
		
		mChanged = false;
		
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
		
		isOverflowing = mShaper.shape(mAtlas.userData, mProperties);
		
		var c, x, y, w, h, g, e, next;
		
		var v = mNode.child;
		var a = mShaper.data;
		var z = 0;
		var i = 0;
		var k = mShaper.numChars * 5;
		while (i < k)
		{
			c = Std.int(a[i++]);
			x = a[i++];
			y = a[i++];
			w = a[i++];
			h = a[i++];
			
			if (v != null)
			{
				//reuse existing visual
				g = as(v, Glyph);
				g.name = String.fromCharCode(c);
				g.cullingMode = CullingMode.CullDynamic;
				mNode.setChildIndex(g, z++);
				v = v.mSibling;
			}
			else
			{
				//create new visual
				g = new Glyph(String.fromCharCode(c));
				e = new TextureEffect().setTexture(mTexture, mAtlas);
				g.effect = e;
				mNode.addChildAt(g, z++);
			}
			
			//set position and frame
			g.local.setTranslate2(x, y);
			g.local.setScale2(w, h);
			g.mFlags |= Spatial.IS_WORLD_XFORM_DIRTY; //TODO why?? force updateGeometricState()
			g.effect.as(TextureEffect).setFrameIndex(c);
		}
		
		//cull/remove unused quads
		i = 0;
		while (v != null)
		{
			if (i++ < 100) //keep no more than
			{
				mHasSleepingQuads = true;
				as(v, Glyph).idleTime = 0;
				v.cullingMode = CullingMode.CullAlways;
				v = v.mSibling;
			}
			else
			{
				//remove
				next = v.mSibling;
				mNode.removeChild(v);
				v.free();
				v = next;
			}
		}
		
		return this;
	}
	
	override function get_width():Float
	{
		return getCharBounds(true).w;
	}
	
	override function get_height():Float
	{
		return getCharBounds(true).h;
	}
	
	override function set_width(value:Float):Float
	{
		return throw "unsupported operation";
	}
	
	override function set_height(value:Float):Float
	{
		return throw "unsupported operation";
	}
	
	override function set_scaleX(value:Float):Float
	{
		assert(!mSpatial.isNode(), "A SpriteText object only supports uniform scaling.");
		
		return value;
	}
	
	override function set_scaleY(value:Float):Float
	{
		assert(!mSpatial.isNode(), "A SpriteText object only supports uniform scaling.");
		
		return value;
	}
	
	function bsearch(lo:Int, hi:Int):Int
	{
		var l = lo, h = hi, s = -1;
		var m = l + ((h - l) >> 1);
		while (true)
		{
			mProperties.size = m;
			if (mShaper.shape(mAtlas.userData, mProperties))
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
	public var looseBounds = new Aabb2();
	public var tightBounds = new Aabb2();
	
	public var outQuads = new Array<Float>();
	public var outCodes = new Array<Int>();
	
	public var data = new Array<Float>();
	public var numChars = 0;
	
	var mCharCodes = new Vector<Int>(4096);
	
	public function new()
	{
	}
	
	public function shape(charSet:BitmapCharSet, properties:SpriteTextProperties):Bool
	{
		numChars = 0;
		
		var str = properties.text;
		
		if (str.length == 0) return false;
		
		var bmpCharLut = charSet.characters;
		var codes = mCharCodes, code;
		
		var numInputChars = 0;
		for (i in 0...str.length)
		{
			code = str.charCodeAt(i);
			if (bmpCharLut[code] != null)
				codes.set(numInputChars++, code);
		}
		
		var boxW = properties.width;
		var boxH = properties.height;
		var kerning = properties.kerning;
		var tracking = properties.tracking;
		var align = properties.align;
		
		var kerningLut = charSet.kerning;
		
		var scale = properties.size / charSet.renderedSize;
		var stepY = (charSet.lineHeight + properties.leading) * scale;
		var numLines = Std.int(boxH / stepY);
		if (numLines == 0) return true;
		if (!properties.multiline) numLines = 1;
		
		var lastCode = 0;
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
		
		inline function getKerning(first:Int, second:Int):Int
		{
			//var x = kerningLut.hasKey(second << 16 | first) ? kerningLut.get(second << 16 | first) : 0;
			//trace('kern ${String.fromCharCode(first)} -> ${String.fromCharCode(second)}  = $x');
			return kerningLut.hasKey(second << 16 | first) ? kerningLut.get(second << 16 | first) : 0;
		}
		
		inline function nextLine()
		{
			newline = true;
			cursorX = 0.;
			cursorY += stepY;
		}
		
		looseBounds.empty();
		tightBounds.empty();
		
		inline function output(code:Int, bc:BitmapChar)
		{
			var minX = cursorX + bc.offsetX * scale;
			var minY = cursorY + bc.offsetY * scale;
			
			data[next++] = code;
			data[next++] = minX;
			data[next++] = minY;
			data[next++] = bc.w * scale;
			data[next++] = bc.h * scale;
			numChars++;
			
			var maxX = minX + bc.w * scale;
			var maxY = minY + bc.h * scale;
			
			tightBounds.addPoint(minX, minY);
			tightBounds.addPoint(maxX, maxY);
			
			looseBounds.addPoint(minX, minY);
			looseBounds.addPoint(maxX, cursorY + charSet.base * scale);
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
			
			//scan forward, testing if the segment fits into the current line
			j = i;
			charCountCurrent = 0;
			x = cursorX;
			y = cursorY;
			code = codes[j];
			bc = bmpCharLut[code];
			
			segmentMinX = x + bc.offsetX * scale;
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
				
				if (segmentMaxX > boxW) break; //horizontal isOverflowing?
				
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
				lastCode = 0;
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
						
						if (cursorX > boxW) //horizontal isOverflowing?
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