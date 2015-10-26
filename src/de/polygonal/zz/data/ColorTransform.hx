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

using de.polygonal.core.math.Mathematics;

class ColorTransform
{
	inline static var INV_FF = .00392156862745098;
	
	inline public static function lerp(a:ColorTransform, b:ColorTransform, alpha:Float, output:ColorTransform):ColorTransform
	{
		var oneMinusAlpha = 1 - alpha, t, u, v;
		
		t = a.multiplier;
		u = b.multiplier;
		v = output.multiplier;
		v.r = t.r * oneMinusAlpha + u.r * alpha;
		v.g = t.g * oneMinusAlpha + u.g * alpha;
		v.b = t.b * oneMinusAlpha + u.b * alpha;
		v.a = t.a * oneMinusAlpha + u.a * alpha;
		
		t = a.offset;
		u = b.offset;
		v = output.offset;
		v.r = t.r * oneMinusAlpha + u.r * alpha;
		v.g = t.g * oneMinusAlpha + u.g * alpha;
		v.b = t.b * oneMinusAlpha + u.b * alpha;
		v.a = t.a * oneMinusAlpha + u.a * alpha;
		return output;
	}
	
	inline public static function concat(a:ColorTransform, b:ColorTransform, output:ColorTransform):ColorTransform
	{
		output.multiplier.r = a.multiplier.r + b.multiplier.r;
		output.multiplier.g = a.multiplier.g + b.multiplier.g;
		output.multiplier.b = a.multiplier.b + b.multiplier.b;
		return output;
	}
	
	public var multiplier(default, null):Colorf;
	public var offset(default, null):Colorf;
	
	public function new(redMultiplier = 1., greenMultiplier = 1., blueMultiplier = 1., alphaMultiplier = 1.,
		redOffset = 0., greenOffset = 0., blueOffset = 0., alphaOffset = 0.)
	{
		multiplier = new Colorf(redMultiplier, greenMultiplier, blueMultiplier, alphaMultiplier);
		offset = new Colorf(redOffset, greenOffset, blueOffset, alphaOffset);
	}
	
	public function free()
	{
		multiplier = null;
		offset = null;
	}
	
	inline public function setMultiplier(rgb:Float, alpha = -1.)
	{
		var t = multiplier;
		t.r = rgb;
		t.g = rgb;
		t.b = rgb;
		if (alpha != -1) t.a = alpha;
	}
	
	inline public function setOffset(rgb:Float, alpha = -1.)
	{
		var t = offset;
		t.r = rgb;
		t.g = rgb;
		t.b = rgb;
		if (alpha != -1) t.a = alpha;
	}
	
	/**
		@param color tinting color in the 0xRRGGBB format.
		@param percent percentage to apply the tint color in <arg>&#091;0, 1&#093;</arg>.
	**/
	inline public function setTint(color:Int, percent:Float)
	{
		throw 'TODO';
		/*var oneMinusMultiplier = 1. - percent;
		setMultiplier(oneMinusMultiplier);
		offset.r = Std.int(color.getR() * percent);
		offset.g = Std.int(color.getG() * percent);
		offset.b = Std.int(color.getB() * percent);*/
	}
	
	/**
		@param x the brightness value in <arg>&#091;-1, 1&#093;</arg>.
	**/
	inline public function setBrightness(x:Float)
	{
		x = x.fclamp(-1, 1);
		setMultiplier(1 - x.fabs());
		setOffset(x > 0 ? x * 255 : 0);
	}
	
	/**
		Apply this color transformation to the given <code>color</code>.
	**/
	inline public function transform(color:Colorf):Colorf
	{
		var m = multiplier;
		var o = offset;
		color.r = color.r * m.r + o.r * INV_FF;
		color.g = color.g * m.g + o.g * INV_FF;
		color.b = color.b * m.b + o.b * INV_FF;
		color.a = color.a * m.a + o.a * INV_FF;
		return color;
	}
	
	/**
		Apply this color transformation to the given <code>color</code> in 0xAARRGGBB format.
	**/
	inline public function transformRGBA(color:Int):Int
	{
		throw 'TODO';
		/*var m = multiplier;
		var o = offset;
		return Rgba.ofFloat4
		(
			(color.getR() * m.r + o.r) * INV_FF,
			(color.getG() * m.g + o.g) * INV_FF,
			(color.getB() * m.b + o.b) * INV_FF,
			(color.getA() * m.a + o.a) * INV_FF
		);*/
	}
}