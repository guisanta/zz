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
package de.polygonal.zz.texture.atlas.format;

import de.polygonal.core.math.Coord2.Coord2i;
import de.polygonal.core.math.Rect.Recti;
import de.polygonal.ds.IntIntHashTable;
import de.polygonal.zz.data.Size.Sizei;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat;

using Std;

/**
	Converts a "Bitmap Font Generator" (http://www.angelcode.com/products/bmfont/) .fnt file to a
	`TextureAtlasDataFormat` object.
**/
class BmFontFormat implements TextureAtlasFormat
{
	var mSrc:Dynamic;
	
	public function new(src:Dynamic)
	{
		mSrc = src;
	}
	
	public function getAtlas():TextureAtlasDef
	{
		var data:TextureAtlasDef = {size: new Sizei(), scale: 1., frames: []};
		
		var file = new BmFontFile(mSrc);
		var charSet = new BitmapCharSet();
		charSet.renderedSize = file.info.size;
		charSet.lineHeight = file.common.lineHeight;
		charSet.base = file.common.base;
		charSet.textureWidth = file.common.scaleW;
		charSet.textureHeight = file.common.scaleH;
		
		data.size.x = charSet.textureWidth;
		data.size.y = charSet.textureHeight;
		
		data.userData = charSet;
		
		for (char in file.chars)
		{
			var code = char.id;
			
			var bc = new BitmapChar();
			bc.code = char.id;
			bc.x = char.x;
			bc.y = char.y;
			bc.offsetX = char.xoffset;
			bc.offsetY = char.yoffset;
			bc.advanceX = char.xadvance;
			bc.w = char.width;
			bc.h = char.height;
			
			charSet.characters[bc.code] = bc;
			
			if (code == -1) continue;
			
			data.frames.push({index: code, name: String.fromCharCode(code), cropRect: new Recti(bc.x, bc.y, bc.w, bc.h),
				trimFlag: false, untrimmedSize: new Sizei(bc.w, bc.h), trimOffset: new Coord2i()});
		}
		
		for (pair in file.kerningPairs)
			charSet.kerning.set((pair.second << 16) | pair.first, pair.amount);
			
		return data;
	}
}

@:publicFields
@:allow(de.polygonal.zz.texture.atlas.format.BmFontFormat)
class BitmapChar
{
	var code(default, null) = -1;
	var x(default, null) = 0;
	var y(default, null) = 0;
	var w(default, null) = 0;
	var h(default, null) = 0;
	var offsetX(default, null) = 0;
	var offsetY(default, null) = 0;
	var advanceX(default, null) = 0;
	
	function new() {}
	
	function toString():String
	{
		return '{BitmapChar: code=$code, x=$x, y=$y, w=$w, h=$h, offsetX=$offsetX, offsetY=$offsetY, advanceX=$advanceX}';
	}
}

@:publicFields
@:allow(de.polygonal.zz.texture.atlas.format.BmFontFormat)
class BitmapCharSet
{
	var characters(default, null):Array<BitmapChar>;
	var kerning(default, null):IntIntHashTable;
	var renderedSize(default, null):Int;
	var textureWidth(default, null):Int;
	var textureHeight(default, null):Int;
	var lineHeight(default, null):Int;
	var base(default, null):Int;
	
	function new()
	{
		characters = new Array<BitmapChar>();
		for (i in 0...256) characters[i] = new BitmapChar();
		kerning = new IntIntHashTable(4096);
	}
	
	function free()
	{
		characters = null;
		if (kerning != null)
		{
			kerning.free();
			kerning = null;
		}
	}
	
	function toString():String
	{
		return '{BitmapCharSet: lineHeight=$lineHeight, base=$base, renderedSize=$renderedSize, textureWidth=$textureWidth, textureHeight=$textureHeight}';
	}
}

private typedef FntChar = { id:Int, x:Int, y:Int, width:Int, height:Int, xoffset:Int, yoffset:Int, xadvance:Int }
private typedef FntKerningPair = { first:Int, second:Int, amount:Int }
private typedef FntInfo = { size:Int }
private typedef FntCommon = { lineHeight:Int, base:Int, scaleW:Int, scaleH:Int }

/**
	Parser for the text format used by the [Bitmap Font Generator](http://www.angelcode.com/products/bmfont/) application.
**/
private class BmFontFile
{
	public var info:FntInfo;
	
	public var common:FntCommon;
	
	public var chars:Array<FntChar>;
	
	public var kerningPairs:Array<FntKerningPair>;
	
	public function new(src:Dynamic)
	{
		chars = [];
		kerningPairs = [];
		
		try
		{
			if (Std.is(src, haxe.io.Bytes))
				parseBinary(src);
			else
			if (Std.is(src, String))
			{
				if (~/<\?xml version="1.0"\?>/.match(src))
					parseXml(src);
				else
					parseText(src);
			}
			else
				throw "invalid source file";
		}
		catch(error:Dynamic)
		{
			throw 'invalid .fnt file ($error)';
		}
	}
	
	function parseBinary(src:haxe.io.Bytes)
	{
		var input = new haxe.io.BytesInput(src);
		
		var b = input.readByte();
		var m = input.readByte();
		var f = input.readByte();
		if (b != 66 || m != 77 || f != 70) throw "not a BMF file";
		
		if (input.readByte() != 3) throw "invalid version (must be 3)";
		
		//Block type 1: info
		var blockType = input.readByte();
		var blockSize = input.readInt32();
		var fontSize = input.readInt16();
		var bitField = input.readByte();
		var charSet = input.readByte();
		var stretchH = input.readUInt16();
		var aa = input.readByte();
		var paddingUp = input.readByte();
		var paddingRight = input.readByte();
		var paddingDown = input.readByte();
		var paddingLeft = input.readByte();
		var spacingHoriz = input.readByte();
		var spacingVert = input.readByte();
		var outline = input.readByte();
		var name = input.readString(blockSize - 14);
		
		info = {size: fontSize};
		
		//Block type 2: common
		var blockType = input.readByte();
		var blockSize = input.readInt32();
		
		var lineHeight = input.readUInt16();
		var base = input.readUInt16();
		var scaleW = input.readUInt16();
		var scaleH = input.readUInt16();
		var pages = input.readUInt16();
		var bitField = input.readByte();
		var alphaChnl = input.readByte();
		var redChnl = input.readByte();
		var greenChnl = input.readByte();
		var blueChnl = input.readByte();
		
		common =
		{
			lineHeight: lineHeight,
			base: base,
			scaleW: scaleW,
			scaleH: scaleH
		};
		
		//Block type 3: pages
		var blockType = input.readByte();
		var blockSize = input.readInt32();
		
		var a = input.position;
		var s = input.readUntil(0);
		var b = input.position;
		var len = b - a;
		blockSize -= len;
		while (blockSize > 0)
		{
			var s = input.readUntil(0);
			blockSize -= len;
		}
		
		//Block type 4: chars
		var blockType = input.readByte();
		var blockSize = input.readInt32();
		
		var numChars = Std.int(blockSize / 20);
		for (i in 0...numChars)
		{
			var id = input.readInt32();
			var x = input.readUInt16();
			var y = input.readUInt16();
			var width = input.readUInt16();
			var height = input.readUInt16();
			var xoffset = input.readInt16();
			var yoffset = input.readInt16();
			var xadvance = input.readInt16();
			var page = input.readByte();
			var chnl = input.readByte();
			
			chars.push
			({
				id: id,
				x: x,
				y: y,
				width: width,
				height: height,
				xoffset: xoffset,
				yoffset: yoffset,
				xadvance: xadvance
			});
		}
		
		//Block type 5: kerning pairs
		if (input.position == input.length) return;
		
		var blockType = input.readByte();
		var blockSize = input.readInt32();
		
		while (input.position < input.length)
		{
			var first = input.readInt32();
			var second = input.readInt32();
			var amount = input.readInt16();
			
			kerningPairs.push
			({
				first: first,
				second: second,
				amount: amount
			});
		}
	}
	
	function parseXml(src:String)
	{
		var fast = new haxe.xml.Fast(Xml.parse(src).firstElement());
		
		info = { size: Std.int(Math.abs(fast.node.info.att.size.parseInt())) }
		
		common =
		{
			lineHeight: fast.node.common.att.lineHeight.parseInt(),
			base: fast.node.common.att.base.parseInt(),
			scaleW: fast.node.common.att.scaleW.parseInt(),
			scaleH: fast.node.common.att.scaleH.parseInt()
		};
		
		for (e in fast.node.chars.nodes.char)
		{
			chars.push
			({
				id: e.att.id.parseInt(),
				x: e.att.x.parseInt(),
				y: e.att.y.parseInt(),
				width: e.att.width.parseInt(),
				height: e.att.height.parseInt(),
				xoffset: e.att.xoffset.parseInt(),
				yoffset: e.att.yoffset.parseInt(),
				xadvance:  e.att.xadvance.parseInt()
			});
		}
		
		if (fast.hasNode.kernings)
		{
			for (e in fast.node.kernings.nodes.kerning)
			{
				kerningPairs.push
				({
					first: e.att.first.parseInt(),
					second: e.att.second.parseInt(),
					amount: e.att.amount.parseInt()
				});
			}
		}
	}
	
	function parseText(src:String)
	{
		var lines = ~/\r\n/g.match(src) ? src.split("\r\n") : src.split("\n");
		
		var nextLine = 0;
		
		var reInfo =~/^info face=".*?" size=(-?\d+)/;
		
		reInfo.match(lines[nextLine++]);
		
		info = {size: Std.int(Math.abs(reInfo.matched(1).parseInt()))};
		
		var reCommon = ~/^common lineHeight=(\d+) base=(\d+) scaleW=(\d+) scaleH=(\d+)/;
		reCommon.match(lines[nextLine++]);
		
		common =
		{
			lineHeight: reCommon.matched(1).parseInt(),
			base: reCommon.matched(2).parseInt(),
			scaleW: reCommon.matched(3).parseInt(),
			scaleH: reCommon.matched(4).parseInt()
		};
		
		var reChars = ~/chars count=(\d+)/;
		var reChar = ~/^char id=(\d+)\s+x=(\d+)\s+y=(\d+)\s+width=(\d+)\s+height=(\d+)\s+xoffset=(-?\d+)\s+yoffset=(-?\d+)\s+xadvance=(\d+)/;
		
		var reKernings = ~/kernings count=(\d+)/;
		var reKerning = ~/kerning first=(\d+)\s+second=(\d+)\s+amount=(-?\d+)/;
		
		var numChars = 0;
		var maxChars = 0;
		var numKernings = 0;
		var maxKernings = 0;
		
		var first, other, kern;
		
		while (nextLine < lines.length)
		{
			var line = lines[nextLine++];
			
			if (maxChars == 0)
			{
				if (reChars.match(line))
					maxChars = reChars.matched(1).parseInt();
			}
			else
			if (numChars < maxChars)
			{
				reChar.match(line);
				
				chars.push
				({
					id: reChar.matched(1).parseInt(),
					x: reChar.matched(2).parseInt(),
					y: reChar.matched(3).parseInt(),
					width: reChar.matched(4).parseInt(),
					height: reChar.matched(5).parseInt(),
					xoffset: reChar.matched(6).parseInt(),
					yoffset: reChar.matched(7).parseInt(),
					xadvance: reChar.matched(8).parseInt(),
				});
				
				numChars++;
			}
			else
			if (maxKernings == 0)
			{
				if (reKernings.match(line))
					maxKernings = reKernings.matched(1).parseInt();
			}
			else
			if (numKernings < maxKernings)
			{
				reKerning.match(line);
				kerningPairs.push
				({
					first: reKerning.matched(1).parseInt(),
					second: reKerning.matched(2).parseInt(),
					amount: reKerning.matched(3).parseInt()
				});
				numKernings++;
			}
		}
	}
}