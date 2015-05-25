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
package de.polygonal.zz.data;

import de.polygonal.ds.Vector;

/**
	Helper class for working with color values.
	
	The byte order for each channel when stored in little-endian is BGRA (left = lowest address).
**/
class Color
{
	/**
		Creates a 24-bit RGB color from 8-bit channels in the 0xRRGGBB format.
	**/
	inline public static function makeR8G8B8(red:Int, green:Int, blue:Int)
	{
		return red << 16 | green << 8 | blue;
	}
	
	/**
		Creates a 32-bit RGBA color from 8-bit channels in the 0xAARRGGBB format.
	**/
	inline public static function makeR8G8B8A8(red:Int, green:Int, blue:Int, alpha:Int)
	{
		return alpha << 24 | red << 16 | green << 8 | blue;
	}
	
	/**
		Extracts 8-bit channels from a 24-bit RGB `color`.
		
		E.g. the color channels of 0xRRGGBB are written to `output` in this order: [0xRR, 0xGG, 0xBB].
	**/
	inline public static function extractR8G8B8(color:Int, output:Vector<Int>)
	{
		output[0] = color >> 16 & 0xFF;
		output[1] = color >> 8 & 0xFF;
		output[2] = color & 0xFF;
	}
	
	/**
		Extracts 8-bit channels from a 32-bit RGBA `color`.
		
		E.g. the color channels of 0xAARRGGBB are written to `output` in this order: [0xRR, 0xGG, 0xBB, 0xAA].
	**/
	inline public static function extractR8G8B8A8(color:UInt, output:Vector<Int>)
	{
		output[0] = color >> 16 & 0xFF;
		output[1] = color >> 8 & 0xFF;
		output[2] = color & 0xFF;
		output[3] = color >>> 24;
	}
	
	/**
		Reads the 8-bit red channel `color`.
	**/
	inline public static function rr(color:UInt):Int return color >> 16 & 0xFF;
	
	/**
		Writes the 8-bit `red` channel to `color`.
	**/
	inline public static function wr(color:UInt, red:Int):UInt return ((red & 0xFF) << 16) | (color & 0xff00ffff);
	
	/**
		Reads the 8-bit green channel from `color`.
	**/
	inline public static function rg(color:UInt):Int return color >> 8 & 0xFF;
	
	/**
		Writes the 8-bit `green` channel to `color`.
	**/
	inline public static function wg(color:UInt, green:Int):UInt return ((green & 0xFF) << 8) | (color & 0xffff00ff);
	
	/**
		Reads the 8-bit blue channel from `color`.
	**/
	inline public static function rb(color:UInt):Int return color & 0xFF;
	
	/**
		Writes the 8-bit `blue` channel to `color`.
	**/
	inline public static function wb(color:UInt, blue:Int):UInt return (blue & 0xFF) | (color & 0xffffff00);
	
	/**
		Reads the 8-bit alpha channel from `color`.
	**/
	inline public static function ra(color:UInt):Int return color >>> 24 & 0xFF;
	
	/**
		Writes the 8-bit `alpha` channel to `color`.
	**/
	inline public static function wa(color:UInt, alpha:Int):UInt return ((alpha & 0xFF) << 24) | (color & 0x00ffffff);
}