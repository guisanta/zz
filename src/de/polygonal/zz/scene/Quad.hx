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

import de.polygonal.core.math.Aabb2;
import de.polygonal.core.math.Coord2.Coord2f;
import de.polygonal.core.math.Limits;
import de.polygonal.motor.geom.containment.PointInsideAabb2;
import de.polygonal.zz.scene.BoxBv;
import de.polygonal.zz.scene.Bv.BvType;

/**
	A Quad represents a rectangle made of two triangles.
	
	By default, vertices are in the range [0,1].
	<pre>
	0      1
	+------+
	|013  /|
	|    / |
	| /    |
	|/  123|
	+------+
	3      2
	</pre>
**/
class Quad extends Visual
{
	inline public static var TYPE = 1;
	
	public static var mScratchCoord = new Coord2f();
	
	public static var getBvTypeFunc:Void->BvType = null;
	
	public function new(?name:String)
	{
		super(name);
		type = TYPE;
	}
	
	/**
		Note: only returns valid results if world bound is up-to-date.
	**/
	override public function pick(point:Coord2f, ?result:PickResult):Int
	{
		if (!worldBound.contains(point)) return 0;
		
		var model = mScratchCoord;
		model.set(0, 0);
		world.applyInverse2(point, model);
		if (PointInsideAabb2.test6(model.x, model.y, 0, 0, 1, 1))
		{
			if (result != null) result.add(this);
			return 1;
		}
		return 0;
	}
	
	override public function getBoundingBox(targetSpace:Spatial, output:Aabb2):Aabb2
	{
		if (this == targetSpace)
		{
			output.minX = 0;
			output.minY = 0;
			output.maxX = 1;
			output.maxY = 1;
			return output;
		}
		
		var c = mScratchCoord;
		var w0 = world;
		
		var minX = Limits.FLOAT_MAX;
		var minY = Limits.FLOAT_MAX;
		var maxX = Limits.FLOAT_MIN;
		var maxY = Limits.FLOAT_MIN;
		
		inline function minMax(c)
		{
			if (c.x < minX) minX = c.x;
			else
			if (c.x > maxX) maxX = c.x;
			
			if (c.y < minY) minY = c.y;
			else
			if (c.y > maxY) maxY = c.y;
		}
		
		if (targetSpace.parent == null)
		{
			c.set(0, 0);
			w0.applyForward2(c, c);
			minMax(c);
			
			c.set(1, 0);
			w0.applyForward2(c, c);
			minMax(c);
			
			c.set(1, 1);
			w0.applyForward2(c, c);
			minMax(c);
			
			c.set(0, 1);
			w0.applyForward2(c, c);
			minMax(c);
		}
		else
		{
			var w1 = targetSpace.world;
			
			c.set(0, 0);
			w0.applyForward2(c, c);
			w1.applyInverse2(c, c);
			minMax(c);
			
			c.set(1, 0);
			w0.applyForward2(c, c);
			w1.applyInverse2(c, c);
			minMax(c);
			
			c.set(1, 1);
			w0.applyForward2(c, c);
			w1.applyInverse2(c, c);
			minMax(c);
			
			c.set(0, 1);
			w0.applyForward2(c, c);
			w1.applyInverse2(c, c);
			minMax(c);
		}
		
		output.minX = minX;
		output.minY = minY;
		output.maxX = maxX;
		output.maxY = maxY;
		
		return output;
	}
	
	override function updateModelBound()
	{
		super.updateModelBound();
		
		modelBound.center.x = .5;
		modelBound.center.y = .5;
		modelBound.radius = Math.sqrt(.5);
		switch (modelBound.type)
		{
			case BvType.Box:
				var o:BoxBv = cast modelBound;
				o.minX = 0;
				o.minY = 0;
				o.maxX = 1;
				o.maxY = 1;
			
			case _:
		}
	}
	
	override function getBvType():BvType
	{
		if (getBvTypeFunc != null) return getBvTypeFunc();
		return super.getBvType();
	}
}