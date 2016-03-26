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
package de.polygonal.zz.tools.uax14;

import haxe.io.Bytes;

/**
	See https://github.com/devongovett/tiny-inflate
**/
class TinyInflate
{
	static var TINF_OK = 0;
	static var TINF_DATA_ERROR = -3;
	
	public static function run(source:Bytes, dest:Bytes):Bytes
	{
		var length_bits = [for (i in 0...30) 0];
		var length_base = [for (i in 0...30) 0];
		var dist_bits = [for (i in 0...30) 0];
		var dist_base = [for (i in 0...30) 0];
		var clcidx = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];
		var offs = [for (i in 0...16) 0];
		var lengths = [for (i in 0...288 + 32) 0];
		
		var code_tree = new Tree();
		var sltree = new Tree();
		var sdtree = new Tree();
		
		var d = new Data(source, dest);
		
		inline function tinf_build_fixed_trees(lt:Tree, dt:Tree)
		{
			for (i in 0...7) lt.table[i] = 0;
			
			lt.table[7] = 24;
			lt.table[8] = 152;
			lt.table[9] = 112;
			
			for (i in 0...24) lt.trans[i] = 256 + i;
			for (i in 0...144) lt.trans[24 + i] = i;
			for (i in 0...8) lt.trans[24 + 144 + i] = 280 + i;
			for (i in 0...112) lt.trans[24 + 144 + 8 + i] = 144 + i;
			for (i in 0...5) dt.table[i] = 0;
			
			dt.table[5] = 32;
			
			for (i in 0...32) dt.trans[i] = i;
		}
		
		inline function tinf_build_bits_base(bits:Array<Int>, base:Array<Int>, delta:Int, first:Int)
		{
			for (i in 0...delta) bits[i] = 0;
			for (i in 0...30 - delta) bits[i + delta] = Std.int(i / delta);
			var sum = first;
			for (i in 0...30)
			{
				base[i] = sum;
				sum += 1 << bits[i];
			}
		}
		
		inline function tinf_getbit(d:Data):Int
		{
			var x = d.bitcount--;
			if (x == 0)
			{
				d.tag = d.getSrc(d.sourceIndex++);
				d.bitcount = 7;
			}
			
			var bit = d.tag & 1;
			d.tag >>>= 1;
			
			return bit;
		}
		
		inline function tinf_read_bits(d:Data, num:Int, base:Int):Int
		{
			if (num == 0) return base;
			
			while (d.bitcount < 24)
			{
				d.tag |= d.getSrc(d.sourceIndex++) << d.bitcount;
				d.bitcount += 8;
			}
			
			var val = d.tag & (0xffff >>> (16 - num));
			d.tag >>>= num;
			d.bitcount -= num;
			
			return val + base;
		}
		
		inline function tinf_decode_symbol(d:Data, t:Tree):Int
		{
			while (d.bitcount < 24)
			{
				d.tag |= (d.getSrc(d.sourceIndex++) << d.bitcount);
				d.bitcount += 8;
			}
			
			var sum = 0, cur = 0, len = 0;
			var tag = d.tag;
			
			do
			{
				cur = 2 * cur + (tag & 1);
				tag >>>= 1;
				++len;
				sum += t.table[len];
				cur -= t.table[len];
			}
			while (cur >= 0);
			
			d.tag = tag;
			d.bitcount -= len;
			
			return t.trans[sum + cur];
		}
		
		inline function tinf_build_tree(t:Tree, lengths:Array<Int>, off:Int, num:Int)
		{
			for (i in 0...16) t.table[i] = 0;
			for (i in 0...num) t.table[lengths[off + i]]++;
			
			t.table[0] = 0;
			var sum = 0;
			for (i in 0...16)
			{
				offs[i] = sum;
				sum += t.table[i];
			}
			
			for (i in 0...num)
				if (lengths[off + i] != 0)
					t.trans[offs[lengths[off + i]]++] = i;
		}
		
		function tinf_inflate_uncompressed_block(d:Data):Int
		{
			var length, invlength;
			
			while (d.bitcount > 8)
			{
				d.sourceIndex--;
				d.bitcount -= 8;
			}
			
			length = d.getSrc(d.sourceIndex + 1);
			length = 256 * length + d.getSrc(d.sourceIndex);
			
			invlength = d.getSrc(d.sourceIndex + 3);
			invlength = 256 * invlength + d.getSrc(d.sourceIndex + 2);
			
			if (length != (~invlength & 0x0000ffff)) return TINF_DATA_ERROR;
			
			d.sourceIndex += 4;
			
			var i = length;
			while (i > 0)
			{
				d.setDst(d.destLen++, d.getSrc(d.sourceIndex++));
				i--;
			}
			
			d.bitcount = 0;
			
			return TINF_OK;
		}
		
		function tinf_inflate_block_data(d:Data, lt:Tree, dt:Tree):Int
		{
			while (true)
			{
				var sym = tinf_decode_symbol(d, lt);
				
				if (sym == 256) return TINF_OK;
				
				if (sym < 256)
				{
					d.setDst(d.destLen++, sym);
				}
				else
				{
					var length, dist, offs;
					var i;
					
					sym -= 257;
					
					length = tinf_read_bits(d, length_bits[sym], length_base[sym]);
					
					dist = tinf_decode_symbol(d, dt);
					
					offs = d.destLen - tinf_read_bits(d, dist_bits[dist], dist_base[dist]);
					
					for (i in offs...offs + length)
						d.setDst(d.destLen++, d.getDst(i));
				}
			}
		}
		
		function tinf_decode_trees(d:Data, lt:Tree, dt:Tree)
		{
			var hlit, hdist, hclen;
			
			hlit = tinf_read_bits(d, 5, 257);
			hdist = tinf_read_bits(d, 5, 1);
			hclen = tinf_read_bits(d, 4, 4);
			
			for (i in 0...19) lengths[i] = 0;
			for (i in 0...hclen) lengths[clcidx[i]] = tinf_read_bits(d, 3, 0);
			
			tinf_build_tree(code_tree, lengths, 0, 19);
			
			var num = 0;
			while (num < hlit + hdist)
			{
				var sym = tinf_decode_symbol(d, code_tree);
				switch (sym)
				{
					case 16:
						var prev = lengths[num - 1];
						var l = tinf_read_bits(d, 2, 3);
						while (l > 0)
						{
							lengths[num++] = prev;
							l--;
						}
					
					case 17:
						var l = tinf_read_bits(d, 3, 3);
						while (l > 0)
						{
							lengths[num++] = 0;
							l--;
						}
					
					case 18:
						var l = tinf_read_bits(d, 7, 11);
						while (l > 0)
						{
							lengths[num++] = 0;
							l--;
						}
					
					case _:
						lengths[num++] = sym;
				}
			}
			
			tinf_build_tree(lt, lengths, 0, hlit);
			tinf_build_tree(dt, lengths, hlit, hdist);
		}
		
		tinf_build_fixed_trees(sltree, sdtree);
		tinf_build_bits_base(length_bits, length_base, 4, 3);
		tinf_build_bits_base(dist_bits, dist_base, 2, 1);
		length_bits[28] = 0;
		length_base[28] = 258;
		
		var bfinal, res;
		
		do
		{
			bfinal = tinf_getbit(d);
			switch (tinf_read_bits(d, 2, 0))
			{
				case 0:
					res = tinf_inflate_uncompressed_block(d);
				
				case 1:
					res = tinf_inflate_block_data(d, sltree, sdtree);
				
				case 2:
					tinf_decode_trees(d, d.ltree, d.dtree);
					res = tinf_inflate_block_data(d, d.ltree, d.dtree);
				
				case _:
					res = TINF_DATA_ERROR;
			}
			
			if (res != TINF_OK) throw 'Data error';
		}
		while (bfinal == 0);
		
		if (d.destLen < d.dest.length) d.dest = d.dest.sub(0, d.destLen);
		
		return d.dest;
	}
}

@:publicFields
private class Tree
{
	var table = new Array<Int>();
	var trans = new Array<Int>();
	
	public function new()
	{
		table = [for (i in 0...16) 0];
		trans = [for (i in 0...288) 0];
	}
}

@:publicFields
private class Data
{
	var source:Bytes;
	var sourceIndex = 0;
	var tag = 0;
	var bitcount = 0;
	var dest:Bytes;
	var destLen = 0;
	var ltree = new Tree();
	var dtree = new Tree();
	
	public function new(source:Bytes, dest:Bytes)
	{
		this.source = source;
		this.dest = dest;
	}
	
	inline function getSrc(pos:Int):Int return source.get(pos);
	inline function getDst(pos:Int):Int return dest.get(pos);
	inline function setDst(pos:Int, v) dest.set(pos, v);
}