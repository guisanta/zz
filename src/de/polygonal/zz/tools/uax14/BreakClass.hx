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

/**
	An implementation of the Unicode Line Breaking Algorithm (UAX #14)
	See https://github.com/devongovett/linebreak
**/
class BreakClass
{
	//The following break classes are handled by the pair table
	
	inline public static var OP = 0;  //  # Opening punctuation
	inline public static var CL = 1;  //  # Closing punctuation
	inline public static var CP = 2;  //  # Closing parenthesis
	inline public static var QU = 3;  //  # Ambiguous quotation
	inline public static var GL = 4;  //  # Glue
	inline public static var NS = 5;  //  # Non-starters
	inline public static var EX = 6;  //  # Exclamation/Interrogation
	inline public static var SY = 7;  //  # Symbols allowing break after
	inline public static var IS = 8;  //  # Infix separator
	inline public static var PR = 9;  //  # Prefix
	inline public static var PO = 10; //  # Postfix
	inline public static var NU = 11; //  # Numeric
	inline public static var AL = 12; //  # Alphabetic
	inline public static var HL = 13; //  # Hebrew Letter
	inline public static var ID = 14; //  # Ideographic
	inline public static var IN = 15; //  # Inseparable characters
	inline public static var HY = 16; //  # Hyphen
	inline public static var BA = 17; //  # Break after
	inline public static var BB = 18; //  # Break before
	inline public static var B2 = 19; //  # Break on either side (but not pair)
	inline public static var ZW = 20; //  # Zero-width space
	inline public static var CM = 21; //  # Combining marks
	inline public static var WJ = 22; //  # Word joiner
	inline public static var H2 = 23; //  # Hangul LV
	inline public static var H3 = 24; //  # Hangul LVT
	inline public static var JL = 25; //  # Hangul L Jamo
	inline public static var JV = 26; //  # Hangul V Jamo
	inline public static var JT = 27; //  # Hangul T Jamo
	inline public static var RI = 28; //  # Regional Indicator
	
	//The following break classes are not handled by the pair table
	
	inline public static var AI = 29; //  # Ambiguous (Alphabetic or Ideograph)
	inline public static var BK = 30; //  # Break (mandatory)
	inline public static var CB = 31; //  # Contingent break
	inline public static var CJ = 32; //  # Conditional Japanese Starter
	inline public static var CR = 33; //  # Carriage return
	inline public static var LF = 34; //  # Line feed
	inline public static var NL = 35; //  # Next line
	inline public static var SA = 36; //  # South-East Asian
	inline public static var SG = 37; //  # Surrogates
	inline public static var SP = 38; //  # Space
	inline public static var XX = 39; //  # Unknown
}