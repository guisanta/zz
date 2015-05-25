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
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

Title : BitmapFont.cs
Author : Chad Vernon
URL : http://www.c-unit.com

Description : Bitmap font wrapper based on the Angelcode bitmap font generator.
	http://www.angelcode.com/products/bmfont/

Created :  12/20/2005
Modified : 12/22/2005

Copyright (c) 2006 C-Unit.com

This software is provided 'as-is', without any express or implied warranty. In no event will 
the authors be held liable for any damages arising from the use of this software.

Permission is granted to anyone to use this software for any purpose, including commercial 
applications, and to alter it and redistribute it freely, subject to the following restrictions:

    1. The origin of this software must not be misrepresented; you must not claim that you wrote 
       the original software. If you use this software in a product, an acknowledgment in the 
       product documentation would be appreciated but is not required.

    2. Altered source versions must be plainly marked as such, and must not be misrepresented 
       as being the original software.

    3. This notice may not be removed or altered from any source distribution.

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
package de.polygonal.zz.sprite;

import de.polygonal.core.fmt.Ascii;
import de.polygonal.core.math.Aabb2;
import de.polygonal.core.math.Limits;
import de.polygonal.core.math.Mathematics.M;
import de.polygonal.core.math.Rect.Rectf;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.ds.Bits;
import de.polygonal.ds.Da;
import de.polygonal.ds.IntIntHashTable;
import de.polygonal.zz.render.effect.TextureEffect;
import de.polygonal.zz.scene.CullingMode;
import de.polygonal.zz.scene.Quad;
import de.polygonal.zz.scene.Node;
import de.polygonal.zz.scene.Spatial;
import de.polygonal.zz.texture.atlas.format.BmFontFormat.BitmapChar;
import de.polygonal.zz.texture.atlas.format.BmFontFormat;
import de.polygonal.zz.texture.Texture;
import de.polygonal.zz.texture.atlas.TextureAtlas;
import de.polygonal.zz.texture.TextureLib;

enum TextAlign
{
	Center;
	Left;
	Right;
}

@:access(de.polygonal.zz.scene.Spatial)
class SpriteText extends SpriteBase
{
	inline static var DISPOSE_INACTIVE_GLYPH_TIMEOUT = 10;
	inline static var MAX_INACTIVE_GLYPHS = 100;
	
	/**
		Defines the letter spacing.
	**/
	public var tracking = 0.;
	
	/**
		Defines line spacing.
	**/
	public var leading = 0.;
	
	/**
		If false, kerning is ignored.
	**/
	public var kerning = true;
	
	/**
		if != -1, the width of each glyph is overriden by this value.
	**/
	public var monospaceWidth = -1;
	
	public var textAlign:TextAlign = TextAlign.Left;
	
	var mNode:Node;
	
	var mAtlas:TextureAtlas;
	var mTexture:Texture;
	
	var mText:String;
	var mTextBox:Rectf;
	var mSize:Float;
	var mQuads:Array<FontQuad>;
	var mNumQuads:Int;
	
	var mBound:Aabb2;
	
	public function new(textureId:Int, ?parent:SpriteGroup)
	{
		super(new Node('text[$textureId]'));
		mNode = cast mSpatial;
		
		mTexture = TextureLib.getTexture(textureId);
		mAtlas = mTexture.atlas;
		
		mQuads = [];
		mNumQuads = 0;
		mBound = new Aabb2(0, 0, 0, 0);
		
		if (parent != null) parent.addChild(this);
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
		mTextBox = null;
		textAlign = null;
		mQuads = null;
		mBound = null;
	}
	
	override function get_width():Float
	{
		commit();
		return mBound.w * M.fabs(scaleX);
	}
	
	override function get_height():Float
	{
		commit();
		return mBound.h * M.fabs(scaleY);
	}
	
	override function get_size():Float
	{
		return mSize;
	}
	
	override function set_size(value:Float):Float
	{
		mSize = value;
		mNumQuads = processFontQuads();
		setDirty();
		return value;
	}
	
	override public function centerPivot()
	{
		commit();
		mPivotX = mBound.x + mBound.w / 2;
		mPivotY = mBound.y + mBound.h / 2;
		setDirty();
		super.commit();
	}
	
	public function setText(text:String, ?box:Rectf, ?align:TextAlign, size:Float = 0)
	{
		mText = text;
		
		mTextBox = box;
		if (mTextBox == null)
		{
			mTextBox = new Rectf(0, 0, Limits.INT16_MAX, Limits.INT16_MAX);
			#if debug
			if (align != null)
				assert(align == TextAlign.Left);
			#end
		}
		textAlign = align == null ? Left : align;
		mSize = size == 0 ? cast(mAtlas.userData, BitmapCharSet).renderedSize : size;
		mNumQuads = processFontQuads();
		setDirty();
	}
	
	public function setBox(box:Rectf)
	{
		assert(box != null);
		
		mTextBox = box;
		
		mNumQuads = processFontQuads();
		setDirty();
	}
	
	public function updateText(text:String)
	{
		assert(mTextBox != null, "call setText() first");
		
		if (text == mText) return;
		mText = text;
		mNumQuads = processFontQuads();
		setDirty();
	}
	
	override public function tick(timeDelta:Float)
	{
		//remove culled glyphs after an idle time of 10 seconds
		var child = mNode.child;
		var g:SpriteTextQuad;
		while (child != null)
		{
			if (child.mFlags & Spatial.CULL_ALWAYS > 0)
			{
				g = cast child;
				g.inactiveTime += timeDelta;
				if (g.inactiveTime > DISPOSE_INACTIVE_GLYPH_TIMEOUT)
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
	
	override public function commit()
	{
		var dirty = getDirty();
		
		super.commit();
		
		if (dirty)
		{
			var minX = M.POSITIVE_INFINITY;
			var minY = M.POSITIVE_INFINITY;
			var maxX = M.NEGATIVE_INFINITY;
			var maxY = M.NEGATIVE_INFINITY;
			
			//cull existing quads
			var oldCount = 0;
			var child = mNode.child;
			while (child != null)
			{
				oldCount++;
				child.cullingMode = CullingMode.CullAlways;
				child = child.mSibling;
			}
			child = mNode.child;
			
			var quad:FontQuad, char:BitmapChar, code:Int, glyph:SpriteTextQuad;
			for (i in 0...mNumQuads)
			{
				quad = mQuads[i];
				char = quad.bitmapChar;
				code = char.code;
				
				//skip characters that are white space or not included in the sprite sheet
				if (code == -1 || (code > 8 && code < 14) || code == 32) continue;
				
				if (oldCount > 0)
				{
					//reuse existing visual
					glyph = cast child;
					child = child.mSibling;
					oldCount--;
					
					glyph.name = String.fromCharCode(code);
					glyph.cullingMode = CullingMode.CullDynamic;
				}
				else
				{
					//create new visual
					glyph = new SpriteTextQuad(String.fromCharCode(code));
					
					var e = new TextureEffect();
					e.setTexture(mTexture, mAtlas);
					glyph.effect = e;
					
					mNode.addChildAt(glyph, 0); //draw in reverse order
				}
				
				//set position and frame
				glyph.local.setTranslate2(quad.minX, quad.minY);
				glyph.local.setScale2(char.w * quad.sizeScale, char.h * quad.sizeScale);
				glyph.mFlags |= Spatial.IS_WORLD_XFORM_DIRTY; //calls updateGeometricState()
				cast(glyph.effect, TextureEffect).setFrameIndex(code);
				
				minX = M.fmin(minX, quad.minX);
				minY = M.fmin(minY, quad.minY);
				maxX = M.fmax(maxX, quad.maxX);
				maxY = M.fmax(maxY, quad.maxY);
			}
			
			mBound.set(minX, minY, maxX, maxY);
			
			//#remove unused remaining visuals
			while (oldCount > 0)
			{
				glyph = cast child;
				glyph.inactiveTime = 0;
				child = child.mSibling;
				oldCount--;
			}
			assert(child == null);
			
			//only keep 100 inactive glyphs alive
			var inactiveCount = 0;
			var child = mNode.child;
			while (child != null)
			{
				if (child.mFlags & Spatial.CULL_ALWAYS > 0)
				{
					if (++inactiveCount == MAX_INACTIVE_GLYPHS)
						break;
				}
				child = child.mSibling;
			}
			while (child != null)
			{
				var next = child.mSibling;
				mNode.removeChild(child);
				child.free();
				child = next;
			}
		}
	}
	
	function processFontQuads():Int
	{
		var charSet = cast(mAtlas.userData, BitmapCharSet);
		var quads = mQuads;
		var maxWidth = mTextBox.w;
		var sizeScale = mSize / charSet.renderedSize;
		
		var bc:BitmapChar = null;
		var q:FontQuad = null;
		
		var overflow = false;
		var newline = false;
		var firstCharOfLine = true;
		
		var lineWidth = 0.;
		var numQuads = 0;
		var code = 0;
		var lastCode = 0;
		var lineNumber = 1;
		var wordNumber = 1;
		var stepX = 0.;
		var offsetX = 0.;
		var wordWidth = 0.;
		var kerningAmount = 0.;
		var kerningVal = 0;
		var key = 0;
		var newlineLastChar = 0;
		
		var x = mTextBox.x;
		var y = mTextBox.y;
		
		//var maxOffsetY = .0;
		
		var mQuadsInLine = new Array<FontQuad>();
		
		for (i in 0...mText.length)
		{
			code = mText.charCodeAt(i);
			
			bc = charSet.characters[code];
			newline = code == Ascii.NEWLINE || code == Ascii.CARRIAGERETURN;
			stepX = (monospaceWidth == -1 ? bc.stepX : monospaceWidth) * sizeScale + tracking;
			overflow = lineWidth + stepX >= maxWidth;
			
			if (y + (bc.offsetY * sizeScale) + ((bc.h * sizeScale)) > mTextBox.b)
			{
				trace('vertical overflow');
				break; //bail out if text overflows vertically
			}
			
			if (newline || overflow)
			{
				//move cursor position to new line
				x =
				switch (textAlign)
				{
					case Left: mTextBox.x;
					case Center: mTextBox.x + maxWidth / 2;
					case Right: mTextBox.r;
				}
				
				//TODO adjust chars
				//TODO make sure chars are inside bounds
				/*for (i in mQuadsInLine) i.setMinY(i.minY - maxOffsetY);
				mQuadsInLine = [];
				y -= maxOffsetY;
				trace( "maxOffsetY : " + maxOffsetY );
				maxOffsetY = 0;*/
				
				
				
				
				
				y += (charSet.lineHeight + leading) * sizeScale;
				
				offsetX = 0;
				
				if (overflow && (wordNumber != 1)) //word wrap
				{
					newlineLastChar = 0;
					lineWidth = 0.;
					
					for (i in 0...numQuads)
					{
						q = quads[i];
						switch (textAlign)
						{
							case Left:
								if ((q.lineNumber == lineNumber) && (q.wordNumber == wordNumber))
								{
									q.lineNumber++; //shift word to next line
									q.wordNumber = 1;
									q.setMinX(x + (q.bitmapChar.offsetX * sizeScale));
									q.setMinY(y + (q.bitmapChar.offsetY * sizeScale));
									x += q.bitmapChar.stepX * sizeScale;
									lineWidth += q.bitmapChar.stepX * sizeScale;
									
									if (kerning)
									{
										key = Bits.packUI16(newlineLastChar, q.code);
										kerningVal = charSet.kerning.get(key);
										if (kerningVal != IntIntHashTable.KEY_ABSENT)
										{
											kerningAmount = kerningVal * sizeScale;
											x += kerningAmount;
											lineWidth += kerningAmount;
										}
									}
								}
							
							case Center:
								if ((q.lineNumber == lineNumber) && (q.wordNumber == wordNumber))
								{
									q.lineNumber++;
									q.wordNumber = 1;
									q.setMinX(x + (q.bitmapChar.offsetX * sizeScale));
									q.setMinY(y + (q.bitmapChar.offsetY * sizeScale));
									x += q.bitmapChar.stepX * sizeScale;
									lineWidth += q.bitmapChar.stepX * sizeScale;
									offsetX += q.bitmapChar.stepX * sizeScale / 2;
									
									if (kerning)
									{
										key = Bits.packUI16(newlineLastChar, q.code);
										
										kerningVal = charSet.kerning.get(key);
										if (kerningVal != IntIntHashTable.KEY_ABSENT)
										{
											kerningAmount = kerningVal * sizeScale;
											x += kerningAmount;
											lineWidth += kerningAmount;
											offsetX += kerningAmount / 2;
										}
									}
								}
							
							case Right:
								if ((q.lineNumber == lineNumber) && (q.wordNumber == wordNumber))
								{
									q.lineNumber++;
									q.wordNumber = 1;
									q.setMinX(x + (q.bitmapChar.offsetX * sizeScale));
									q.setMinY(y + (q.bitmapChar.offsetY * sizeScale));
									lineWidth += q.bitmapChar.stepX * sizeScale;
									x += q.bitmapChar.stepX * sizeScale;
									offsetX += q.bitmapChar.stepX * sizeScale;
									
									if (kerning)
									{
										key = Bits.packUI16(newlineLastChar, q.code);
										
										kerningVal = charSet.kerning.get(key);
										if (kerningVal != IntIntHashTable.KEY_ABSENT)
										{
											kerningAmount = kerningVal * sizeScale;
											x += kerningAmount;
											lineWidth += kerningAmount;
											offsetX += kerningAmount;
										}
									}
								}
						}
						newlineLastChar = q.code;
					}
					
					switch (textAlign)
					{
						case Center, Right:
							for (i in 0...numQuads)
							{
								q = quads[i];
								if (q.lineNumber == lineNumber + 1)
									q.minX -= offsetX;
							}
							x -= offsetX;
							for (i in 0...numQuads)
							{
								q = quads[i];
								if (q.lineNumber == lineNumber)
									q.minX += offsetX;
							}
						default:
					}
				}
				else
				{
					firstCharOfLine = true;
					lineWidth = 0.;
				}
				
				wordNumber = 1;
				lineNumber++;
			}
			
			if (newline || code == Ascii.TAB) continue;
			
			if (firstCharOfLine)
			{
				x =
				switch (textAlign)
				{
					case Left:   mTextBox.x;
					case Center: mTextBox.x + (maxWidth / 2);
					case Right:  mTextBox.r;
				}
				//maxOffsetY = 0;
			}
			
			//compute kerning
			kerningAmount = 0.;
			if (kerning && !firstCharOfLine)
			{
				key = Bits.packUI16(lastCode, mText.charCodeAt(i));
				kerningVal = charSet.kerning.get(key);
				if (kerningVal != IntIntHashTable.KEY_ABSENT)
				{
					kerningAmount = kerningVal * sizeScale;
					x += kerningAmount;
					lineWidth += kerningAmount;
					wordWidth += kerningAmount;
				}
			}
			
			firstCharOfLine = false;
			
			if (code == Ascii.SPACE && textAlign != Left)
			{
				wordNumber++;
				wordWidth = 0;
			}
			wordWidth += stepX;
			
			//initialize font quad
			q = quads[numQuads];
			if (q == null)
			{
				q = new FontQuad();
				quads[numQuads] = q;
			}
			numQuads++;
			q.minX = x + (bc.offsetX * sizeScale);
			q.minY = y + (bc.offsetY * sizeScale);
			q.maxX = q.minX + (bc.w * sizeScale);
			q.maxY = q.minY + (bc.h * sizeScale);
			q.lineNumber = lineNumber;
			q.wordNumber = wordNumber;
			q.wordWidth = wordWidth;
			q.bitmapChar = bc;
			q.sizeScale = sizeScale;
			q.code = code;
			
			mQuadsInLine.push(q);
			
			//maxOffsetY = M.fmin(bc.offsetY, maxOffsetY);
			
			if (code == Ascii.SPACE && textAlign == Left) //start new word?
			{
				wordNumber++;
				wordWidth = 0.;
			}
			
			x += stepX;
			lineWidth += stepX;
			lastCode = mText.charCodeAt(i);
			
			switch (textAlign)
			{
				case Center:
					offsetX = stepX / 2;
					if (kerning) offsetX += kerningAmount / 2;
					
					for (i in 0...numQuads)
					{
						q = quads[i];
						if (q.lineNumber == lineNumber)
							q.setMinX(q.minX - offsetX);
					}
					x -= offsetX;
				
				case Right:
					offsetX = 0.;
					if (kerning) offsetX += kerningAmount;
					
					for (i in 0...numQuads)
					{
						q = quads[i];
						if (q.lineNumber == lineNumber)
						{
							offsetX = stepX;
							q.setMinX(q.minX - stepX);
						}
					}
					x -= offsetX;
				
				case _:
			}
		}
		
		return numQuads;
	}
}

private class SpriteTextQuad extends Quad
{
	public var inactiveTime:Float = 0;
	
	public function new(name:String)
	{
		super(name);
	}
}

@:publicFields
private class FontQuad
{
	var code:Int;
	var lineNumber:Int;
	var wordNumber:Int;
	var wordWidth:Float;
	var sizeScale:Float;
	var minX:Float;
	var minY:Float;
	var maxX:Float;
	var maxY:Float;
	var bitmapChar:BitmapChar;
	
	function new()
	{
	}
	
	inline function setMinX(value:Float)
	{
		var tmp = maxX - minX;
		minX = value;
		maxX = value + tmp;
	}
	
	inline function setMinY(value:Float)
	{
		var tmp = maxY - minY;
		minY = value;
		maxY = value + tmp;
	}
}