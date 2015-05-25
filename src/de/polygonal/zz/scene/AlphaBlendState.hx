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
package de.polygonal.zz.scene;

import de.polygonal.ds.ArrayedStack;
import de.polygonal.zz.scene.GlobalState;

enum AlphaBlendMode
{
	/**
		Ignores alpha thus disables transparency.
	**/
	None;
	
	/**
		Normal alpha blending preset (default).
	**/
	Normal;
	
	/**
		Multiplicative blending mode preset; the result is a darker picture.
	**/
	Multiply;
	
	/**
		Additive blending mode preset (aka linear dodge).
	**/
	Add;
	
	/**
		Screen blending mode preset; the opposite effect to multiply.
	**/
	Screen;
	
	/**
		User defined blending mode.
		Blending eq. Cf = (Cs * P) + (Cd * Q) =
		
		(Cf.r, Cf.g, Cf.b, Cf.a) = (Cs.r*P.r + Cd.r*Q.r, Cs.g*P.g + Cd.g*Q.g, Cs.b*P.b + Cd.b*Q.b, Cs.a*P.a + Cd.a*Q.a)
		
		Cf, Cs, Cd = final, source, destination color
		P = blending coefficient for source color (computed)
		Q = blending coefficient for destination color (already on screen)
		.r, .g, .b, .a = affected color channels
	**/
	User(src:SrcBlendFactor, dst:DstBlendFactor);
}

enum SrcBlendFactor
{
	Zero;
	One;
	DstColor;
	OneMinusDstColor;
	SrcAlpha;
	OneMinusSrcAlpha;
	DstAlpha;
	OneMinusDstAlpha;
}

enum DstBlendFactor
{
	Zero;
	One;
	SrcColor;
	OneMinusSrcColor;
	SrcAlpha;
	OneMinusSrcAlpha;
	DstAlpha;
	OneMinusDstAlpha;
}

class AlphaBlendState extends GlobalState
{
	public static var PRESET_NONE(default, null) = new AlphaBlendState(None);
	public static var PRESET_NORMAL(default, null) = new AlphaBlendState(Normal);
	public static var PRESET_MULTIPLY(default, null) = new AlphaBlendState(Multiply);
	public static var PRESET_ADD(default, null) = new AlphaBlendState(Add);
	public static var PRESET_SCREEN(default, null) = new AlphaBlendState(Screen);
	
	public var alphaBlendMode(default, null):AlphaBlendMode;
	
	public function new(value:AlphaBlendMode)
	{
		super(GlobalStateType.AlphaBlend);
		
		alphaBlendMode = value;
		
		var shift = GlobalState.NUM_STATES;
		bits |= (1 << value.getIndex()) << shift;
		switch (value)
		{
			case User(src, dst):
				bits |= (1 << src.getIndex()) << (shift + 8);
				bits |= (1 << dst.getIndex()) << (shift + 16);
			
			case _:
		}
	}
	
	override public function collapse(stack:ArrayedStack<GlobalState>):GlobalState
	{
		return this;
	}
	
	public function toString():String return '{AlphaBlendState, alphaBlendMode=$alphaBlendMode}';
}