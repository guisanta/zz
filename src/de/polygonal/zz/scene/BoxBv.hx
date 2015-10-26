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

import de.polygonal.core.math.Coord2.Coord2f;
import de.polygonal.core.math.Vec3;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.ds.Bits;
import de.polygonal.motor.geom.containment.PointInsidePlane;
import de.polygonal.motor.geom.data.Plane2;
import de.polygonal.motor.geom.intersection.IntersectAabb2;
import de.polygonal.zz.scene.Bv.BvType;
import haxe.ds.Vector;

/**
	An axis aligned bounding box.
**/
class BoxBv extends Bv
{
	public static var mScratchVec = new Vec3();
	
	public var minX:Float = 0;
	public var minY:Float = 0;
	public var maxX:Float = 0;
	public var maxY:Float = 0;
	
	public function new()
	{
		super(BvType.Box);
	}
	
	override public function computeFromData(data:Vector<Float>)
	{
		minX = minY = maxX = maxY = 0;
		var numElements = data.length >> 1;
		for (i in 0...numElements)
		{
			var x = data[(i << 1)];
			var y = data[(i << 1) + 1];
			if (x < minX) minX = x;
			if (x > maxX) maxX = x;
			if (y < minY) minY = y;
			if (y > maxY) maxY = y;
		}
	}
	
	override public function contains(point:Coord2f):Bool
	{
		return (point.x >= minX) && (point.x <= maxX) && (point.y >= minY) && (point.y <= maxY);
	}
	
	override public function growToContain(other:Bv)
	{
		switch (other.type)
		{
			case BvType.Circle:
				var c = other.center;
				var r = other.radius;
				if (c.x - r < minX) minX = c.x - r;
				if (c.y - r < minY) minY = c.y - r;
				if (c.x + r > maxX) maxX = c.x + r;
				if (c.y + r > maxY) maxY = c.y + r;
			
			case BvType.Box:
				var o = asBox(other);
				if (o.minX < minX) minX = o.minX;
				if (o.minY < minY) minY = o.minY;
				if (o.maxX > maxX) maxX = o.maxX;
				if (o.maxY > maxY) maxY = o.maxY;
		}
		
		var rx = (maxX - minX) / 2;
		var ry = (maxY - minY) / 2;
		center.x = minX + rx;
		center.y = minY + ry;
		radius = Math.sqrt(rx * rx + ry * ry);
	}
	
	override public function of(other:Bv)
	{
		var c = other.center;
		var r = other.radius;
		
		switch (other.type)
		{
			case BvType.Circle:
				minX = c.x - r;
				minY = c.y - r;
				maxX = c.x + r;
				maxY = c.y + r;
			
			case BvType.Box:
				var o = asBox(other);
				minX = o.minX;
				minY = o.minY;
				maxX = o.maxX;
				maxY = o.maxY;
		}
		
		center.x = c.x;
		center.y = c.y;
		radius = r;
	}
	
	override public function whichSide(plane:Plane2):Int
	{
		var nx = plane.n.x;
		var ny = plane.n.y;
		var d = plane.d;
		
		//axis-aligned plane?
		if (nx == 1)
		{
			return
				if (maxX < d)-1;
				else
				if (minX > d) 1;
				else 0;
		}
		else
		if (nx == -1)
		{
			return
				if (minX > -d)-1;
				else
				if (maxX < -d) 1;
				else 0;
		}
		
		if (ny == 1)
		{
			return
				if (maxY < d)-1;
				else
				if (minY > d) 1;
				else 0;
		}
		else
		if (nx == -1)
		{
			return
				if (minY > -d)-1;
				else
				if (maxY < -d) 1;
				else 0;
		}
		
		//tl, tr, bl, br
		var bits = 0;
		bits |= (cast PointInsidePlane.test5(minX, minY, nx, ny, d)) << 0;
		bits |= (cast PointInsidePlane.test5(maxX, minY, nx, ny, d)) << 1;
		bits |= (cast PointInsidePlane.test5(minX, maxY, nx, ny, d)) << 2;
		bits |= (cast PointInsidePlane.test5(maxX, maxY, nx, ny, d)) << 3;
		
		return
			if (bits == Bits.mask(4)) -1;
			else
			if (bits == 0) 1;
			else
			0;
	}
	
	override public function transformBy(transform:Xform, output:Bv)
	{
		super.transformBy(transform, output);
		
		var o = asBox(output);
		
		assert(this != output);
		
		var c = mScratchVec;
		c.x = minX + (maxX - minX) * .5;
		c.y = minY + (maxY - minY) * .5;
		c.z = 0;
		transform.applyForward(c, c);
		
		o.minX = c.x;
		o.minY = c.y;
		o.maxX = c.x;
		o.maxY = c.y;
		
		//refit axis-aligned box to oriented box
		if (transform.isRSMatrix())
		{
			var r = transform.getRotate();
			var scale = transform.getScale();
			var ex = scale.x * .5;
			var ey = scale.y * .5;
			
			if (r.m11 > 0)
			{
				o.minX -= r.m11 * ex;
				o.maxX += r.m11 * ex;
			}
			else
			{
				o.minX += r.m11 * ex;
				o.maxX -= r.m11 * ex;
			}
			if (r.m12 > 0)
			{
				o.minX -= r.m12 * ey;
				o.maxX += r.m12 * ey;
			}
			else
			{
				o.minX += r.m12 * ey;
				o.maxX -= r.m12 * ey;
			}
			if (r.m21 > 0)
			{
				o.minY -= r.m21 * ex;
				o.maxY += r.m21 * ex;
			}
			else
			{
				o.minY += r.m21 * ex;
				o.maxY -= r.m21 * ex;
			}
			if (r.m22 > 0)
			{
				o.minY -= r.m22 * ey;
				o.maxY += r.m22 * ey;
			}
			else
			{
				o.minY += r.m22 * ey;
				o.maxY -= r.m22 * ey;
			}
		}
		else
		{
			//decompose 2x2 matrix
			//http://math.stackexchange.com/questions/78137/decomposition-of-a-nonsquare-affine-matrix
			var m = transform.getMatrix();
			var a = m.m11;
			var b = m.m12;
			var p = Math.sqrt(a * a + b * b);
			var r = (a * m.m22 - b * m.m21) / p;
			var ex = p * .5;
			var ey = r * .5;
			var angle = Math.atan2(b, a);
			var c = Math.cos(angle);
			var s = Math.sin(angle);
			
			if (c > 0)
			{
				o.minX -= c * ex;
				o.maxX += c * ex;
			}
			else
			{
				o.minX += c * ex;
				o.maxX -= c * ex;
			}
			if (s > 0)
			{
				o.minX -= s * ey;
				o.maxX += s * ey;
			}
			else
			{
				o.minX += s * ey;
				o.maxX -= s * ey;
			}
			if (-s > 0)
			{
				o.minY -= -s * ex;
				o.maxY += -s * ex;
			}
			else
			{
				o.minY += -s * ex;
				o.maxY -= -s * ex;
			}
			if (c > 0)
			{
				o.minY -= c * ey;
				o.maxY += c * ey;
			}
			else
			{
				o.minY += c * ey;
				o.maxY -= c * ey;
			}
		}
	}
	
	override public function testIntersect(other:Bv):Bool
	{
		switch (other.type)
		{
			case BvType.Circle:
				return super.testIntersect(other);
			
			case BvType.Box:
				var o = asBox(other);
				return IntersectAabb2.test8(minX, minY, maxX, maxY,
					o.minX, o.minY, o.maxX, o.maxY);
		}
		
		if (other.radius == 0 || radius == 0) return false;
		var dx = center.x - other.center.x;
		var dy = center.y - other.center.y;
		var rsum = radius + other.radius;
		return (dx * dx + dy * dy) <= (rsum * rsum);
	}
	
	inline function asBox(x:Bv):BoxBv
	{
		return
		#if flash
		flash.Lib.as(x, BoxBv);
		#else
		cast x;
		#end
	}
}