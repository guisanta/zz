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
import de.polygonal.core.math.Mathematics;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.ds.ArrayList;
import de.polygonal.ds.IntIntHashTable;
import de.polygonal.zz.data.Size.Sizef;
import de.polygonal.zz.render.effect.TextureEffect;
import de.polygonal.zz.scene.CullingMode;
import de.polygonal.zz.scene.Node;
import de.polygonal.zz.scene.Quad;
import de.polygonal.zz.scene.Spatial.as;
import de.polygonal.zz.scene.Spatial;
import de.polygonal.zz.scene.TreeTools;
import de.polygonal.zz.sprite.SpriteBase.*;
import de.polygonal.zz.texture.atlas.format.BmFontFormat.BitmapChar;
import de.polygonal.zz.texture.atlas.format.BmFontFormat.BitmapCharSet;
import de.polygonal.zz.texture.atlas.TextureAtlas;
import de.polygonal.zz.texture.Texture;
import de.polygonal.zz.texture.TextureLib;
import de.polygonal.zz.tools.uax14.LineBreaker;
import haxe.ds.IntMap;
import de.polygonal.zz.scene.SpatialFlags.*;

enum TextAlign { Left; Center; Right; }

typedef SpriteTextDef =
{
	text:String, size:Int, align:TextAlign, width:Float, height:Float,
	kerning:Bool, multiline:Bool, tracking:Float, leading:Float, ligatures:Int
}

typedef TextLayoutData =
{
	charCodes:ArrayList<Int>, charRects:ArrayList<Float>, //[x0,y0,w0,h0, x1,y1,w1,h1, ...]
	overflow:Bool, bounds:Aabb2
}

interface TextLayoutStrategy
{
	function layout(charSet:BitmapCharSet, def:SpriteTextDef, output:TextLayoutData):Void;
	function free():Void;
}

@:access(de.polygonal.zz.scene.Spatial)
class SpriteText extends SpriteBase
{
	inline public static var TYPE = 3;
	inline public static var FLAG_TRIM = 0x01;
	
	static var _ligatureLut:IntMap<IntIntHashTable> = null;
	
	public static function registerLigature(id:Int, first:String, second:String, ligatureCharCode:Int)
	{
		assert(first.charCodeAt(0) <= 0xffff && second.charCodeAt(0) <= 0xffff);
		
		if (_ligatureLut == null) _ligatureLut = new IntMap();
		if (!_ligatureLut.exists(id)) _ligatureLut.set(id, new IntIntHashTable(16));
		_ligatureLut.get(id).set(second.charCodeAt(0) << 16 | first.charCodeAt(0), ligatureCharCode);
	}
	
	/**
		True if the given text does not fit.
	**/
	public var isOverflowing(get, never):Bool;
	inline function get_isOverflowing():Bool return mTextLayoutResult.overflow;
	
	var mNode:Node;
	var mTexture:Texture;
	var mAtlas:TextureAtlas;
	var mTextLayout:TextLayoutStrategy = new SingleLineTextLayout();
	var mChanged = true;
	var mTextureChanged = false;
	var mHasSleepingQuads = false;
	
	var mDef:SpriteTextDef =
	{
		text: "", size: 10, align: TextAlign.Left, width: 100., height: 100.,
		kerning: true, multiline: false, tracking: 0., leading: 0., ligatures: -1
	}
	
	var mTextLayoutResult:TextLayoutData =
	{
		charCodes: new ArrayList<Int>(64), charRects: new ArrayList<Float>(256),
		overflow: false, bounds: new Aabb2()
	}
	
	public function new(?parent:SpriteGroup, ?textureId:Null<Int>)
	{
		mNode = new Node("SpriteText");
		mNode.mFlags |= SKIP_CHILDREN;
		super(mNode);
		
		type = TYPE;
		
		if (parent != null) parent.addChild(this);
		if (textureId != null)
		{
			setTexture(textureId);
			mDef.size = cast(mAtlas.userData, BitmapCharSet).renderedSize;
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
		mDef = null;
	}
	
	public function getBitmapCharSet():BitmapCharSet
	{
		return mAtlas.userData;
	}
	
	public function getBase():Float
	{
		var cs = getBitmapCharSet();
		var scale = getTextSize() / cs.renderedSize;
		return cs.base * scale;
	}
	
	public function getNumLines():Int
	{
		if (getMultiline())
		{
			var cs = getBitmapCharSet();
			var scale = getTextSize() / cs.renderedSize;
			return Std.int(getTextBoxSize().y / ((cs.lineHeight + getLeading()) * scale));
		}
		return 1;
	}
	
	public function getText():String
	{
		return mDef.text;
	}
	public function setText(value:Dynamic):SpriteText
	{
		mChanged = mChanged || (mDef.text != Std.string(value));
		mDef.text = Std.string(value);
		return this;
	}
	
	public function getTextSize():Int
	{
		return mDef.size;
	}
	public function setTextSize(value:Int):SpriteText
	{
		mChanged = mChanged || (mDef.size != value);
		mDef.size = value;
		return this;
	}
	
	public function getTextBoxSize():Sizef
	{
		return new Sizef(mDef.width, mDef.height);
	}
	public function setTextBoxSize(width:Float, height:Float):SpriteText
	{
		mChanged = mChanged || (mDef.width != width);
		mChanged = mChanged || (mDef.height != height);
		mDef.width = width;
		mDef.height = height;
		return this;
	}
	
	public function getTextAlign():TextAlign
	{
		return mDef.align;
	}
	public function setTextAlign(value:TextAlign):SpriteText
	{
		mChanged = mChanged || (mDef.align != value);
		mDef.align = value;
		return this;
	}
	
	public function getMultiline():Bool
	{
		return mDef.multiline;
	}
	public function setMultiline(value:Bool):SpriteText
	{
		mChanged = mChanged || (mDef.multiline != value);
		mDef.multiline = value;
		if (mChanged) mTextLayout = value ? new MultiLineTextLayout() : new SingleLineTextLayout();
		return this;
	}
	
	public function getKerning():Bool
	{
		return mDef.kerning;
	}
	public function setKerning(value:Bool):SpriteText
	{
		mChanged = mChanged || (mDef.kerning != value);
		mDef.kerning = value;
		return this;
	}
	
	public function getLeading():Float
	{
		return mDef.leading;
	}
	public function setLeading(value:Float):SpriteText
	{
		mChanged = mChanged || (mDef.leading != value);
		mDef.leading = value;
		return this;
	}
	
	public function getTracking():Float
	{
		return mDef.tracking;
	}
	public function setTracking(value:Float):SpriteText
	{
		mChanged = mChanged || (mDef.tracking != value);
		mDef.tracking = value;
		return this;
	}
	
	public function getLigatures():Int
	{
		return mDef.ligatures;
	}
	
	public function setLigatures(value:Int)
	{
		mChanged = mChanged || (mDef.ligatures != value);
		mDef.ligatures = value;
		return this;
	}
	
	public function getTextBounds():Aabb2
	{
		return mTextLayoutResult.bounds.clone();
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
		mChanged = mChanged || (mDef.size != size);
		mDef.size = size;
	}
	
	public function autoFit(minSize:Int, maxSize:Int)
	{
		mDef.size = (maxSize - minSize) >> 1;
		mTextLayout.layout(mAtlas.userData, mDef, mTextLayoutResult);
		var currentSize = mDef.size, bestSize;
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
		bestSize = Mathematics.clamp(bestSize, minSize, maxSize);
		mDef.size = bestSize;
		mChanged = true;
		mTextLayout.layout(mAtlas.userData, mDef, mTextLayoutResult);
	}
	
	public function shrinkToFit(minSize:Int)
	{
		mTextLayout.layout(mAtlas.userData, mDef, mTextLayoutResult);
		if (!isOverflowing) return;
		
		var currentSize = mDef.size;
		if (currentSize < minSize) return;
		
		mDef.size = bsearch(minSize, currentSize - 1);
		mChanged = true;
		mTextLayout.layout(mAtlas.userData, mDef, mTextLayoutResult);
	}
	
	public function growToFit(maxSize:Int)
	{
		mTextLayout.layout(mAtlas.userData, mDef, mTextLayoutResult);
		if (isOverflowing) return;
		
		var currentSize = mDef.size;
		if (currentSize > maxSize) return;
		
		mDef.size = bsearch(currentSize, maxSize + 1);
		
		mChanged = true;
		mTextLayout.layout(mAtlas.userData, mDef, mTextLayoutResult);
	}
	
	public function align9(parentBounds:Aabb2, horizontal:Int, vertical:Int, baseline = true)
	{
		if (mTextLayoutResult.overflow) return;
		if (mTextLayoutResult.bounds.isEmpty()) return;
		
		var textBounds = mTextLayoutResult.bounds;
		
		x =
		if (horizontal < 0)
			parentBounds.minX;
		else
		if (horizontal > 0)
			parentBounds.maxX - textBounds.w;
		else
			parentBounds.cx - (textBounds.w / 2);
		x -= textBounds.minX;
		
		y =
		if (vertical < 0)
			parentBounds.minY - textBounds.minY;
		else
		if (vertical > 0)
			(parentBounds.maxY - textBounds.h) - textBounds.minY;
		else
		{
			if (baseline)
			{
				var cs = getBitmapCharSet();
				var scale = mDef.size / cs.renderedSize;
				var base = cs.base * scale;
				parentBounds.minY + (parentBounds.h / 2 - base);
			}
			else
				(parentBounds.cy - (textBounds.h / 2)) - textBounds.minY;
		}
	}
	
	@:access(de.polygonal.zz.sprite.Sprite)
	override public function getBounds(targetSpace:SpriteBase, ?output:Aabb2, ?flags:Int = 0):Aabb2
	{
		if (targetSpace == null) targetSpace = this;
		if (output == null) output = new Aabb2();
		
		if (flags & Sprite.FLAG_SKIP_WORLD_UPDATE == 0)
		{
			SpriteTools.updateWorldTransform(this);
			if (SpriteTools.isAncestor(this, targetSpace) == false)
				SpriteTools.updateWorldTransform(targetSpace);
		}
		
		return TreeTools.transformBoundingBox(sgn, targetSpace.sgn, getTextBounds(), output);
	}
	
	override public function centerPivot()
	{
		var charBounds = getTextBounds();
		mPivotX = charBounds.cx;
		mPivotY = charBounds.cy;
		mFlags |= HINT_LOCAL_DIRTY;
	}
	
	override public function tick(dt:Float)
	{
		super.tick(dt);
		
		//remove culled glyphs after x seconds
		if (!mHasSleepingQuads) return;
		
		var numSleeping = 0;
		var c = mNode.child, g;
		while (c != null)
		{
			if (c.mFlags & CULL_ALWAYS > 0)
			{
				g = as(c, Glyph);
				g.idleTime += dt;
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
		
		if (mTexture == null || mDef.text == null) return this; //no texture/text defined
		if (!mChanged && !mTextureChanged) return this; //nothing to do
		
		mChanged = false;
		
		if (mTextureChanged)
		{
			//start from scratch
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
		
		mTextLayout.layout(mAtlas.userData, mDef, mTextLayoutResult);
		
		var codes = mTextLayoutResult.charCodes;
		var rects = mTextLayoutResult.charRects;
		
		var v = mNode.child, z = 0, j = 0;
		var c, x, y, w, h, glyph, effect, next;
		for (i in 0...codes.size)
		{
			c = codes.get(i);
			j = i << 2;
			x = rects.get(j + 0);
			y = rects.get(j + 1);
			w = rects.get(j + 2);
			h = rects.get(j + 3);
			
			if (v != null)
			{
				//reuse existing visual
				glyph = as(v, Glyph);
				glyph.name = String.fromCharCode(c);
				glyph.cullingMode = CullingMode.CullDynamic;
				mNode.setChildIndex(glyph, z++);
				v = v.mSibling;
			}
			else
			{
				//create new visual
				glyph = new Glyph(String.fromCharCode(c));
				effect = new TextureEffect().setTexture(mTexture, mAtlas);
				glyph.effect = effect;
				mNode.addChildAt(glyph, z++);
			}
			
			//set position and frame
			glyph.local.setTranslate2(x, y);
			glyph.local.setScale2(w, h);
			glyph.effect.as(TextureEffect).setFrameIndex(c);
		}
		
		mNode.mFlags |= IS_WORLD_XFORM_DIRTY;
		
		//cull/remove unused quads
		var count = 0;
		while (v != null)
		{
			if (count++ < 100) //keep no more than
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
		return getTextBounds().w;
	}
	
	override function get_height():Float
	{
		return getTextBounds().h;
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
			mDef.size = m;
			mTextLayout.layout(mAtlas.userData, mDef, mTextLayoutResult);
			if (isOverflowing)
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

/**
	Simple & fast single line text layout.
**/
class SingleLineTextLayout implements TextLayoutStrategy
{
	var mBitmapChars = new ArrayList<BitmapChar>(32);
	var mCharCodes = new ArrayList<Int>(32);
	
	public function new() {}
	
	public function free()
	{
		mBitmapChars.free();
		mBitmapChars = null;
		
		mCharCodes.free();
		mCharCodes = null;
	}
	
	@:access(de.polygonal.zz.sprite.SpriteText)
	public function layout(charSet:BitmapCharSet, def:SpriteTextDef, output:TextLayoutData)
	{
		var s = def.text, len = s.length;
		
		//make sure there is enough space available for storing output
		var outCharCodes = output.charCodes;
		var outCharRects = output.charRects;
		
		outCharCodes.reserve(len);
		outCharRects.reserve(len);
		outCharCodes.clear();
		outCharRects.clear();
		
		output.overflow = false;
		var bounds = output.bounds;
		bounds.empty();
		
		if (len == 0) return;
		
		var bmpCharLut = charSet.characters, code;
		
		var codes = mCharCodes;
		codes.clear();
		codes.reserve(len);
		for (i in 0...len) codes.unsafePushBack(s.charCodeAt(i));
		
		//test for ligatures
		if (def.ligatures > -1)
		{
			var lut = SpriteText._ligatureLut.get(def.ligatures);
			if (lut != null)
			{
				var i = 0, k = codes.size - 1, first, second;
				while (i < k)
				{
					first = codes.get(i);
					second = codes.get(i + 1);
					if (lut.hasKey(second << 16 | first))
					{
						codes.set(i, lut.get(second << 16 | first));
						codes.removeAt(i + 1);
						k--;
						i++;
						continue;
					}
					i++;
				}
			}
		}
		
		//only draw supported characters
		var bitmapChars = mBitmapChars;
		bitmapChars.clear();
		bitmapChars.reserve(codes.size);
		for (i in 0...codes.size)
		{
			code = codes.get(i);
			if (bmpCharLut.hasKey(code))
				bitmapChars.unsafePushBack(bmpCharLut.get(code));
		}
		
		var boxW = def.width;
		var kerning = def.kerning;
		var align = def.align;
		var kerningLut = charSet.kerning;
		var scale = def.size / charSet.renderedSize;
		var tracking = def.tracking * scale;
		
		var stepY = charSet.lineHeight * scale;
		if (def.height / stepY < 1) //vertical overflow?
		{
			output.overflow = true;
			return;
		}
		
		var bc = bitmapChars.get(0);
		var cursor = -(bc.offsetX * scale);
		
		var padding = charSet.padding;
		var pu = padding.up * scale;
		var pr = padding.right * scale;
		var pd = padding.down * scale;
		var pl = padding.left * scale;
		
		var l, t, w, h;
		
		//write characters, left to right
		var i = 0, k = bitmapChars.size, lastCode = 0;
		var maxX, kerningAmount = 0.;
		while (i < k)
		{
			bc = bitmapChars.get(i++);
			
			//glyph rectangle
			l = cursor + bc.offsetX * scale;
			t = bc.offsetY * scale;
			w = bc.w * scale;
			h = bc.h * scale;
			
			maxX = l + w - pr;
			if (kerning)
			{
				kerningAmount = kerningLut.get((bc.code << 16) | lastCode);
				if (kerningAmount == IntIntHashTable.KEY_ABSENT) kerningAmount = 0;
				kerningAmount *= scale;
				lastCode = bc.code;
				maxX += kerningAmount;
			}
			
			if (maxX > boxW) //horizontal overflow?
			{
				output.overflow = true;
				return;
			}
			
			l += kerningAmount;
			
			//output character code and glyph rectangle
			outCharCodes.unsafePushBack(bc.code);
			outCharRects.unsafePushBack(l);
			outCharRects.unsafePushBack(t);
			outCharRects.unsafePushBack(w);
			outCharRects.unsafePushBack(h);
			
			//update bounding box
			if (!Ascii.isWhite(bc.code))
			{
				bounds.addPoint(l + pl, t + pu);
				bounds.addPoint(l + w - pr, t + h - pd);
			}
			
			//advance cursor
			cursor += bc.advanceX * scale + kerningAmount + tracking;
		}
		
		if (align != TextAlign.Left)
		{
			var offset = boxW - bounds.right;
			if (align == TextAlign.Center) offset /= 2;
			var j;
			for (i in 0...k)
			{
				j = i << 2;
				outCharRects.set(j, outCharRects.get(j) + offset);
			}
			bounds.x += offset;
		}
	}
}

private typedef Break = { string:String, position:Int, required:Bool };

/**
	Multi-line text layout using UAX #14 line break algorithm.
**/
class MultiLineTextLayout implements TextLayoutStrategy
{
	static var _breaker:LineBreaker = null;
	
	var mCharSet:BitmapCharSet;
	var mDef:SpriteTextDef;
	var mOutput:TextLayoutData;
	var mBreakList = new BreakList();
	var mBitmapChars = new ArrayList<BitmapChar>(64);
	var mTmpCharBounds = new Aabb2();
	var mTmpLineBounds = new Aabb2();
	
	public function new()
	{
		if (_breaker == null)
			_breaker = new LineBreaker();
	}
	
	public function free()
	{
		mCharSet = null;
		mDef = null;
		mOutput = null;
		mBreakList.free();
		mBreakList = null;
		mBitmapChars.free();
		mBitmapChars = null;
		mTmpCharBounds = null;
		mTmpLineBounds = null;
	}
	
	public function layout(charSet:BitmapCharSet, def:SpriteTextDef, output:TextLayoutData)
	{
		mCharSet = charSet;
		mDef = def;
		mOutput = output;
		
		output.overflow = false;
		output.bounds.empty();
		
		var s = def.text, len = s.length;
		if (len == 0) return;
		
		//make sure there is enough space available for storing output
		output.charCodes.reserve(len);
		output.charCodes.clear();
		output.charRects.reserve(len);
		output.charRects.clear();
		
		var hasUnsupportedChars = false;
		var bmpCharLut = charSet.characters;
		var bitmapChars = mBitmapChars, code;
		bitmapChars.clear();
		bitmapChars.reserve(len);
		for (i in 0...len)
		{
			code = s.charCodeAt(i);
			if (bmpCharLut.hasKey(code))
				bitmapChars.unsafePushBack(bmpCharLut.get(code));
			else
				hasUnsupportedChars = true;
		}
		
		if (hasUnsupportedChars)
		{
			var buf = new StringBuf();
			for (i in bitmapChars) buf.addChar(i.code);
			s = buf.toString();
		}
		
		var scale = def.size / charSet.renderedSize;
		var stepY = (charSet.lineHeight + def.leading) * scale;
		var numLines = Std.int(def.height / stepY);
		if (numLines == 0)
		{
			output.overflow = true;
			return;
		}
		
		breakText(s);
		
		var cursorX = 0.;
		var cursorY = 0.;
		var line = 1;
		var segMin = 0;
		var segMax = 0;
		var line0 = 0;
		var line1 = 0;
		var firstCharInLine = true;
		var lastSize, newCursorX, overflow = false, brk;
		var charBounds = mTmpCharBounds, lineBounds = mTmpLineBounds;
		var l = mBreakList, i = 0, k = l.size;
		
		inline function nextLine()
		{
			line1 = output.charCodes.size - 1;
			alignLine(def.align, line0, line1, lineBounds);
			line0 = line1;
			
			output.bounds.addOther(lineBounds);
			lineBounds.empty();
			
			cursorX = 0.;
			cursorY += stepY;
			line++;
			firstCharInLine = true;
			overflow = line > numLines;
		}
		
		lineBounds.empty();
		
		while (i < k && !overflow)
		{
			brk = l.get(i);
			
			segMin = segMax;
			segMax = brk.position;
			
			if (firstCharInLine)
			{
				firstCharInLine = false;
				cursorX = -bitmapChars.get(segMin).offsetX * scale;
			}
			
			//write segment
			lastSize = output.charCodes.size;
			newCursorX = write(cursorX, cursorY, segMin, segMax, charBounds);
			overflow = newCursorX == Math.POSITIVE_INFINITY;
			
			if (overflow)
			{
				//discard data
				output.charCodes.trim(lastSize);
				output.charRects.trim(lastSize * 4);
				
				//write again after trimming trailing whitespace
				while (segMax > segMin && Ascii.isWhite(bitmapChars.get(segMax - 1).code)) segMax--;
				lastSize = output.charCodes.size;
				write(cursorX, cursorY, segMin, segMax, charBounds);
				overflow = newCursorX == Math.POSITIVE_INFINITY;
				
				if (overflow)
				{
					//doesn't fit after trimming, so discard data and start next line
					output.charCodes.trim(lastSize);
					output.charRects.trim(lastSize * 4);
					segMax = segMin;
					nextLine();
					continue;
				}
			}
			
			lineBounds.addOther(charBounds);
			
			i++; //next segment
			
			if (brk.required)
				nextLine();
			else
				cursorX = newCursorX;
		}
		
		line1 = output.charCodes.size - 1;
		alignLine(def.align, line0, line1, lineBounds);
		
		output.bounds.addOther(lineBounds);
		output.overflow = i < k;
	}
	
	function breakText(text:String)
	{
		var b = _breaker, l = mBreakList;
		
		b.setText(text);
		l.clear();
		var last = 0, bk;
		while ((bk = b.nextBreak()) != null)
		{
			l.add(text.substring(last, bk.position), bk.position, bk.required);
			last = bk.position;
		}
	}
	
	function write(cursorX:Float, cursorY:Float, segMin:Int, segMax:Int, outBounds:Aabb2):Float
	{
		//returns a finite number if the segments fits into the current line
		var scale = mDef.size / mCharSet.renderedSize;
		var bitmapChars = mBitmapChars;
		var bc = bitmapChars.get(segMin);
		var padding = mCharSet.padding;
		var pu = padding.up * scale;
		var pr = padding.right * scale;
		var pd = padding.down * scale;
		var pl = padding.left * scale;
		var l, t, w, h;
		
		outBounds.empty();
		
		//write characters, left to right
		var maxX, kerningAmount = 0., boxW = mDef.width, lastCode = 0;
		var kerningLut = mCharSet.kerning, kerning = mDef.kerning, tracking = mDef.tracking;
		while (segMin < segMax)
		{
			bc = bitmapChars.get(segMin++);
			
			//glyph rectangle
			l = cursorX + bc.offsetX * scale;
			t = cursorY + bc.offsetY * scale;
			w = bc.w * scale;
			h = bc.h * scale;
			
			maxX = l + w - pr;
			if (kerning)
			{
				kerningAmount = kerningLut.get((bc.code << 16) | lastCode);
				if (kerningAmount == IntIntHashTable.KEY_ABSENT) kerningAmount = 0;
				kerningAmount *= scale;
				lastCode = bc.code;
				maxX += kerningAmount;
			}
			
			//horizontal overflow?
			if (maxX > boxW)
			{
				cursorX = Math.POSITIVE_INFINITY;
				break;
			}
			
			l += kerningAmount;
			
			//output character code and glyph rectangle
			mOutput.charCodes.unsafePushBack(bc.code);
			mOutput.charRects.unsafePushBack(l);
			mOutput.charRects.unsafePushBack(t);
			mOutput.charRects.unsafePushBack(w);
			mOutput.charRects.unsafePushBack(h);
			
			//update bounding box
			if (!Ascii.isWhite(bc.code))
			{
				outBounds.addPoint(l + pl, t + pu);
				outBounds.addPoint(l + w - pr, t + h - pd);
			}
			
			//advance cursor
			cursorX += bc.advanceX * scale + kerningAmount + tracking;
		}
		return cursorX;
	}
	
	function alignLine(align:TextAlign, minCharIndex:Int, maxCharIndex:Int, lineBounds:Aabb2)
	{
		if (align == TextAlign.Left) return;
		
		var dx = mDef.width - lineBounds.maxX;
		if (align == TextAlign.Center) dx /= 2;
		dx = Std.int(dx);
		
		lineBounds.x += dx;
		
		var leftIndex, rects = mOutput.charRects;
		while (minCharIndex <= maxCharIndex)
		{
			leftIndex = minCharIndex << 2;
			rects.set(leftIndex, rects.get(leftIndex) + dx);
			minCharIndex++;
		}
	}
}

private class BreakList
{
	var mData:Array<Break> = [];
	
	public var size(default, null) = 0;
	
	public function new() {};
	
	public function free()
	{
		mData = null;
	}
	
	public inline function clear() size = 0;
	
	public inline function get(i:Int) return mData[i];
	
	public inline function add(string:String, position:Int, required:Bool)
	{
		var o = mData[size];
		if (o == null) o = mData[size] = {string: null, position: -1, required: false}
		o.string = string;
		o.position = position;
		o.required = required;
		size++;
	}
}