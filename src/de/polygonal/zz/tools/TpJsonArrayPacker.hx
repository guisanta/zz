/*
Copyright (c) 2016 Michael Baczynski, http://www.polygonal.de

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
package de.polygonal.zz.tools;

import de.polygonal.core.fmt.StringTools;
import haxe.ds.StringMap;
import haxe.io.Bytes;

using Reflect;

private class Seq
{
	public var name:String;
	public var frames:Array<Dynamic>;
	public function new(name:String)
	{
		this.name = name;
		frames = [];
	}
}

class TpJsonArrayPacker
{
	public static function pack(jsonString:String)
	{
		var o:Dynamic = haxe.Json.parse(jsonString);
		
		var next = 0;
		var map = new StringMap<Int>();
		var seq = new Array<Seq>();
		var individual:Array<Dynamic> = [];
		var r = ~/(\w+)\/(\d{4})/;
		
		for (frame in (o.field("frames") : Array<Dynamic>))
		{
			if (r.match(frame.field("filename")))
			{
				var name = r.matched(1);
				var index = Std.parseInt(r.matched(2));
				
				if (!map.exists(name)) //new sequence?
				{
					//initialize
					map.set(name, next);
					seq[next] = new Seq(name);
					next++;
				}
				
				//add frame to sequence
				seq[map.get(name)].frames[index] = frame;
			}
			else
				individual.push(frame);
		}
		
		var out = new haxe.io.BytesOutput();
		
		function writeFrame(value:Dynamic)
		{
			var hint = 0;
			
			var frame:Dynamic = value.field("frame");
			var x:Int = frame.field("x");
			var y:Int = frame.field("y");
			var w:Int = frame.field("w");
			var h:Int = frame.field("h");
			
			var sourceSize:Dynamic = value.field("sourceSize");
			var sw:Int = sourceSize.field("w");
			var sh:Int = sourceSize.field("h");
			
			var spriteSourceSize:Dynamic = value.field("spriteSourceSize");
			var sx:Int = spriteSourceSize.field("x");
			var sy:Int = spriteSourceSize.field("y");
			
			if ( x <= 255) hint |= 0x01;
			if ( y <= 255) hint |= 0x02;
			if ( w <= 255) hint |= 0x04;
			if ( h <= 255) hint |= 0x08;
			if (sw <= 255) hint |= 0x10;
			if (sh <= 255) hint |= 0x20;
			if (sx <= 255) hint |= 0x40;
			if (sy <= 255) hint |= 0x80;
			out.writeByte(hint);
			
			inline function write(x:Int, mask:Int) hint & mask > 0 ? out.writeByte(x) : out.writeInt16(x);
			
			write( x, 0x01);
			write( y, 0x02);
			write( w, 0x04);
			write( h, 0x08);
			write(sw, 0x10);
			write(sh, 0x20);
			write(sx, 0x40);
			write(sy, 0x80);
			
			var trimmed:Bool = value.field("trimmed");
			out.writeByte(trimmed ? 1 : 0);
		}
		
		var meta:Dynamic = o.field("meta");
		var size:Dynamic = meta.field("size");
		var w = size.field("w");
		var h = size.field("h");
		var scale = meta.field("scale");
		
		out.writeByte("T".code);
		out.writeByte("P".code);
		out.writeByte("J".code);
		
		out.writeInt16(w);
		out.writeInt16(h);
		out.writeDouble(scale);
		
		out.writeInt16(individual.length);
		for (frame in individual)
		{
			var name = frame.field("filename");
			out.writeInt16(StringTools.utf8Len(name));
			out.writeString(name);
			writeFrame(frame);
		}
		
		out.writeInt16(seq.length);
		for (i in seq)
		{
			var frames = i.frames;
			out.writeInt16(frames.length);
			out.writeInt16(StringTools.utf8Len(i.name));
			out.writeString(i.name);
			for (frame in frames) writeFrame(frame);
		}
		
		return out.getBytes();
	}
	
	public static function unpack(bytes:Bytes):String
	{
		var inp = new haxe.io.BytesInput(bytes);
		
		var a = inp.readByte();
		var b = inp.readByte();
		var c = inp.readByte();
		
		if (String.fromCharCode(a) + String.fromCharCode(b) + String.fromCharCode(c) != "TPJ")
			throw "invalid tp json array file";
		
		function readFrame():Dynamic
		{
			var hint = inp.readByte();
			
			inline function read(mask:Int) return hint & mask > 0 ? inp.readByte() : inp.readInt16();
			
			var f = {};
			var frame = {};
			f.setField("frame", frame);
			frame.setField("x", read(0x01));
			frame.setField("y", read(0x02));
			frame.setField("w", read(0x04));
			frame.setField("h", read(0x08));
			var sourceSize = {};
			f.setField("sourceSize", sourceSize);
			sourceSize.setField("w", read(0x10));
			sourceSize.setField("h", read(0x20));
			var spriteSourceSize = {};
			f.setField("spriteSourceSize", spriteSourceSize);
			spriteSourceSize.setField("x", read(0x40));
			spriteSourceSize.setField("y", read(0x80));
			f.setField("trimmed", inp.readByte() == 1 ? true : false);
			return f;
		}
		
		var frames = [];
		
		var meta = {};
		var size = {};
		meta.setField("size", size);
		size.setField("w", inp.readInt16());
		size.setField("h", inp.readInt16());
		meta.setField("scale", inp.readDouble());
		
		var o = {};
		o.setField("frames", frames);
		o.setField("meta", meta);
		
		var n;
		n = inp.readInt16();
		for (i in 0...n)
		{
			var name = inp.readString(inp.readInt16());
			var f = readFrame();
			f.filename = name;
			frames.push(f);
		}
		
		n = inp.readInt16();
		for (i in 0...n)
		{
			var numFrames = inp.readInt16();
			var name = inp.readString(inp.readInt16());
			var digits:String;
			for (j in 0...numFrames)
			{
				var f = readFrame();
				
				digits = "" + j;
				if (j < 1000) digits = "0" + digits;
				if (j < 100)  digits = "0" + digits;
				if (j < 10)   digits = "0" + digits;
				f.filename = name + "/" + digits;
				frames.push(f);
			}
		}
		return haxe.Json.stringify(o);
	}
}