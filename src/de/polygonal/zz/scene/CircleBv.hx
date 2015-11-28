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

Geometric Tools, LLC
Copyright (c) 1998-2012
Distributed under the Boost Software License, Version 1.0.
http://www.boost.org/LICENSE_1_0.txt
http://www.geometrictools.com/License/Boost/LICENSE_1_0.txt
*/
package de.polygonal.zz.scene;

import de.polygonal.core.math.Coord2f;
import de.polygonal.core.math.Mathematics.M;
import de.polygonal.motor.geom.data.Plane2;
import de.polygonal.motor.geom.distance.DistancePointPlane;
import de.polygonal.zz.scene.Bv;
import haxe.ds.Vector;

/**
	A bounding circle.
**/
class CircleBv extends Bv
{
	public function new()
	{
		super(BvType.Circle);
	}
	
	override public function computeFromData(data:Vector<Float>)
	{
		var numElements = data.length >> 1;
		
		 //center is the average of the positions.
		var sumX = 0.;
		var sumY = 0.;
		for (i in 0...numElements)
		{
			sumX += data[(i << 1)];
			sumY += data[(i << 1) + 1];
		}
		var cx = center.x = sumX / numElements;
		var cy = center.y = sumY / numElements;
		
		//radius is the largest distance from the center to the positions.
		radius = 0;
		for (i in 0...numElements)
		{
			var diffX = data[(i << 1)] - cx;
			var diffY = data[(i << 1) + 1] - cy;
			var radiusSqr = diffX * diffX + diffY * diffY;
			radius = M.fmax(radiusSqr, radius);
		}
		radius = Math.sqrt(radius);
	}
	
	override public function contains(point:Coord2f):Bool
	{
		var dx = point.x - center.x;
		var dy = point.y - center.y;
		return (dx * dx + dy * dy) <= (radius * radius);
	}
	
	override public function growToContain(other:Bv)
	{
		var dx = other.center.x - center.x;
		var dy = other.center.y - center.y;
		var dr = other.radius - radius;
		var lSqr = dx * dx + dy * dy;
		if (dr * dr >= lSqr)
		{
			if (dr >= 0)
				of(other);
			else
				return;
		}
		else
		{
			var l = Math.sqrt(lSqr);
			var t = (l + other.radius - radius) / (2 * l);
			center.x += t * dx;
			center.y += t * dy;
			radius = (l + radius + other.radius) / 2;
		}
	}
	
	override public function of(other:Bv)
	{
		center.x = other.center.x;
		center.y = other.center.y;
		radius = other.radius;
	}
	
	override public function whichSide(plane:Plane2):Int
	{
		var n = plane.n;
		
		var signedDistance = DistancePointPlane.find5(center.x, center.y, n.x, n.y, plane.d);
		return
			if (signedDistance <= -radius) -1;
			else
			if (signedDistance >= radius) 1;
			else
			0;
	}
}