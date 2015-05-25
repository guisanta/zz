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

import de.polygonal.core.math.Coord2;
import de.polygonal.core.math.Vec3;
import de.polygonal.motor.geom.data.Plane2;
import haxe.ds.Vector;
import de.polygonal.core.util.Assert.assert;

@:enum
abstract BvType(Int)
{
	var Circle = 1;
	var Box = 2;
}

/**
	A bounding volume.
	
	At the lowest level, any bounding volume must define a center and a radius. You can think of it
	as a bounding sphere for the bounding volume.
**/
class Bv
{
	public var center:Vec3;
	
	public var radius:Float;
	
	public var type(default, null):BvType;
	
	function new(type:BvType)
	{
		this.type = type;
		center = new Vec3();
		radius = 0;
	}
	
	public function free()
	{
		center = null;
	}
	
	/**
		Computes a box that contains all points stored in `data`.
	**/
	public function computeFromData(data:Vector<Float>) {}
	
	/**
		Returns true if this bounding volume contains `point`.
	**/
	public function contains(point:Coord2f):Bool return throw "override for implementation";
	
	/**
		Modifies this bounding volume so that it contains itself and `other`.
	**/
	public function growToContain(other:Bv) {}
	
	/**
		Copies `other` to this.
	**/
	public function of(other:Bv) {}
	
	/**
		Determines if the bounding volume is on one side of the plane, the other side, or intersects the plane.
		
		- returns 1 if the bounding volume lies completely in front of the plane (on the positive side).
		- returns -1 if the bounding volume lies completely behind the plane (on the negative side)
		- returns 0 if the bounding volume intersects the plane.
	**/
	public function whichSide(plane:Plane2):Int return throw "override for implementation";
	
	/**
		Transforms this bounding volume (e.g. model-to-world transformation).
	**/
	public function transformBy(transform:Xform, output:Bv)
	{
		assert(type == output.type);
		
		transform.applyForward(center, output.center);
		output.radius = transform.getNorm2() * radius;
	}
	
	/**
		Returns true if this bound and `other` intersects.
	**/
	public function testIntersect(other:Bv):Bool
	{
		if (other.radius == 0 || radius == 0) return false;
		var dx = center.x - other.center.x;
		var dy = center.y - other.center.y;
		var rsum = radius + other.radius;
		return (dx * dx + dy * dy) <= (rsum * rsum);
	}
}