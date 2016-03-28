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
import de.polygonal.ds.ArrayList;
import de.polygonal.zz.scene.Spatial.as;

using de.polygonal.ds.tools.NativeArrayTools;

/**
	Scene graph helper functions.
**/
@:access(de.polygonal.zz.scene.Spatial)
class TreeTools
{
	static var _aSpatial = new Array<Spatial>();
	static var _tmpCoord = new Coord2f();
	
	static var _spatialStack = new ArrayList<Spatial>();
	
	/**
		Returns an iterator over all descendants of `root`.
		
		_Uses a non-allocating, iterative traversal._
	**/
	public static function descendantsIterator(root:Node):Iterator<Spatial>
	{
		var a = _aSpatial;
		var top = 0, n:Node, s:Spatial, k:Int, p:Int, c:Spatial;
		
		n = root;
		k = n.numChildren;
		p = top + k;
		c = n.child;
		while (c != null)
		{
			a[p++] = c;
			c = c.mSibling;
		}
		for (i in 0...k)
		{
			a[top++] = a[--p];
			a[p] = null;
		}
		
		return
		{
			hasNext: function()
			{
				return top > 0;
			},
			next: function()
			{
				var s = a[--top];
				a[top] = null;
				
				if (s.isNode())
				{
					n = as(s, Node);
					k = n.numChildren;
					p = top + k;
					
					c = n.child;
					while (c != null)
					{
						a[p++] = c;
						c = c.mSibling;
					}
					
					for (i in 0...k)
					{
						a[top++] = a[--p];
						a[p] = null;
					}
				}
				return s;
			}
		}
	}
	
	public static function descendants(root:Node, output:Array<Spatial>):Int
	{
		var k = 0;
		var a = _aSpatial;
		a[0] = root;
		var top = 1, s:Spatial;
		while (top != 0)
		{
			s = a[--top];
			a[top] = null;
			
			output[k++] = s;
			
			if (s.isNode())
			{
				s = as(s, Node).child;
				while (s != null)
				{
					a[top++] = s;
					s = s.mSibling;
				}
			}
		}
		
		return k;
	}
	
	public static function size(root:Node):Int
	{
		var a = _spatialStack, s:Spatial = root, top = 1, k = 0, n, c;
		a.clear();
		a.pushBack(s);
		while (top > 0)
		{
			s = a.popBack();
			top--;
			
			if (s.isNode())
			{
				n = as(s, Node);
				k += n.numChildren + 1;
				
				if (n.numChildNodes > 0)
				{
					top += n.numChildNodes;
					if (top > a.capacity) a.reserve(top);
					
					c = n.child;
					while (c != null)
					{
						if (c.isNode()) a.pushBack(as(c, Node));
						c = c.mSibling;
					}
				}
			}
		}
		a.getData().nullify(top);
		return k;
	}
	
	/**
		Recomputes world transformations of all nodes along the path from `origin` to root.
	**/
	public static function updateWorldTransformAt(origin:Spatial)
	{
		var top = 0;
		var a = _aSpatial;
		
		var p = origin;
		while (p != null)
		{
			a[top++] = p;
			p = p.parent;
		}
		
		p = a[--top];
		a[top] = null;
		p.mFlags &= ~Spatial.IS_WORLD_XFORM_DIRTY;
		p.world.of(p.local);
		
		while (top > 0)
		{
			var c = a[--top];
			a[top] = null;
			c.mFlags &= ~Spatial.IS_WORLD_XFORM_DIRTY;
			if (!c.worldTransformCurrent)
				c.world.setProduct2(p.world, c.local); //W' = Wp * L
			p = c;
		}
	}
	
	/**
		Recomputes world transformations (and bounding volumes if `updateBound` is true) of the nodes
		stored in the subtree rooted at `origin', including 'origin'.
		
		_This method uses an efficient iterative algorithm that does minimal work._
	**/
	public static function updateGeometricState(root:Node, updateBound = true)
	{
		var a = _spatialStack, s:Spatial = root, top = 1, n, c;
		a.clear();
		a.pushBack(s);
		
		var mask = Spatial.IS_WORLD_XFORM_DIRTY;
		if (updateBound) mask |= Spatial.IS_WORLD_BOUND_DIRTY;
		
		while (a.size > 0)
		{
			s = a.popBack();
			top--;
			
			if (s.mFlags & mask > 0)
			{
				s.updateGeometricState(true, updateBound);
				
				//descendants are updated as a "side effect" of the update rooted at this node, so
				//we can safely the entire subtree rooted at this node.
				continue;
			}
			if (s.isNode())
			{
				n = as(s, Node);
				top += n.numChildren;
				if (top > a.capacity) a.reserve(top);
				c = n.child;
				while (c != null)
				{
					a.unsafePushBack(c);
					c = c.mSibling;
				}
			}
		}
		
		a.getData().nullify(top);
	}
	
	public static function updateRenderState(root:Node)
	{
		//update global states
		var a = _aSpatial;
		a[0] = root;
		var top = 1, s:Spatial, n:Node;
		while (top != 0)
		{
			s = a[--top];
			a[top] = null;
			
			if (s.mFlags & Spatial.IS_RS_DIRTY > 0)
			{
				//descendants are updated as a "side effect" of the update rooted at this node, so
				//we can safely skip the subtree.
				s.updateRenderState();
				continue;
			}
			
			if (s.isNode())
			{
				n = as(s, Node);
				var c = n.child;
				while (c != null)
				{
					a[top++] = c;
					c = c.mSibling;
				}
			}
		}
	}
	
	public static function getBoundingBox(root:Node, targetSpace:Spatial, output:Aabb2):Aabb2
	{
		var minX = Limits.FLOAT_MAX;
		var minY = Limits.FLOAT_MAX;
		var maxX = Limits.FLOAT_MIN;
		var maxY = Limits.FLOAT_MIN;
		
		var c = _tmpCoord;
		
		inline function minMax()
		{
			if (c.x < minX) minX = c.x;
			if (c.x > maxX) maxX = c.x;
			if (c.y < minY) minY = c.y;
			if (c.y > maxY) maxY = c.y;
		}
		
		var a = _aSpatial;
		a[0] = root;
		var top = 1, s:Spatial, n:Node, c;
		while (top != 0)
		{
			s = a[--top];
			a[top] = null;
			
			if (s.isVisual())
			{
				s.getBoundingBox(targetSpace, output);
				
				if (output.minX < minX) minX = output.minX;
				if (output.minY < minY) minY = output.minY;
				if (output.maxX > maxX) maxX = output.maxX;
				if (output.maxY > maxY) maxY = output.maxY;
			}
			else
			if (s.isNode())
			{
				n = as(s, Node);
				c = n.child;
				while (c != null)
				{
					a[top++] = c;
					c = c.mSibling;
				}
			}
		}
		
		output.minX = minX;
		output.minY = minY;
		output.maxX = maxX;
		output.maxY = maxY;
		
		return output;
	}
	
	public static function transformBoundingBox(spatial:Spatial, targetSpace:Spatial, input:Aabb2, output:Aabb2):Aabb2
	{
		var iMinX = input.minX;
		var iMinY = input.minY;
		var iMaxX = input.maxX;
		var iMaxY = input.maxY;
		
		var oMinX = Limits.FLOAT_MAX;
		var oMinY = Limits.FLOAT_MAX;
		var oMaxX = Limits.FLOAT_MIN;
		var oMaxY = Limits.FLOAT_MIN;
		
		var c = new Coord2f();
		
		inline function minMax(c)
		{
			if (c.x < oMinX) oMinX = c.x;
			if (c.x > oMaxX) oMaxX = c.x;
			if (c.y < oMinY) oMinY = c.y;
			if (c.y > oMaxY) oMaxY = c.y;
		}
		
		if (targetSpace == spatial)
			output.of(input);
		else
		if (targetSpace == spatial.parent) //targetSpace is parent of this
		{
			var t = spatial.local;
			c.set(iMinX, iMinX); t.applyForward2(c, c); minMax(c);
			c.set(iMaxX, iMinY); t.applyForward2(c, c); minMax(c);
			c.set(iMaxX, iMaxY); t.applyForward2(c, c); minMax(c);
			c.set(iMinX, iMaxY); t.applyForward2(c, c); minMax(c);
		}
		else
		if (targetSpace.parent == null) //targetSpace is root
		{
			var t = spatial.world;
			c.set(iMinX, iMinX); t.applyForward2(c, c); minMax(c);
			c.set(iMaxX, iMinY); t.applyForward2(c, c); minMax(c);
			c.set(iMaxX, iMaxY); t.applyForward2(c, c); minMax(c);
			c.set(iMinX, iMaxY); t.applyForward2(c, c); minMax(c);
		}
		else
		{
			var t = spatial.world;
			var u = targetSpace.world;
			
			c.set(iMinX, iMinX);
			t.applyForward2(c, c);
			u.applyInverse2(c, c);
			minMax(c);
			
			c.set(iMaxX, iMinY);
			t.applyForward2(c, c);
			u.applyInverse2(c, c);
			minMax(c);
			
			c.set(iMaxX, iMaxY);
			t.applyForward2(c, c);
			u.applyInverse2(c, c);
			minMax(c);
			
			c.set(iMinX, iMaxY);
			t.applyForward2(c, c);
			u.applyInverse2(c, c);
			minMax(c);
		}
		
		output.minX = oMinX;
		output.minY = oMinY;
		output.maxX = oMaxX;
		output.maxY = oMaxY;
		
		return output;
	}
	
	public static function clearSpecialFlags(root:Node)
	{
		var a = _aSpatial;
		a[0] = root;
		var top = 1, s:Spatial, n:Node;
		while (top != 0)
		{
			s = a[--top];
			a[top] = null;
			s.mFlags &= ~Spatial.GS_UPDATED;
			
			if (s.isNode())
			{
				n = as(s, Node);
				var c = n.child;
				while (c != null)
				{
					a[top++] = c;
					c = c.mSibling;
				}
			}
		}
	}
}