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
import de.polygonal.core.math.Coord2f;
import de.polygonal.core.math.Limits;
import de.polygonal.zz.scene.Spatial.as;

/**
	Scene graph helper functions.
**/
@:access(de.polygonal.zz.scene.Spatial)
class TreeUtil
{
	static var _stackSpatial = new Array<Spatial>();
	static var _scratchCoord = new Coord2f();
	
	/**
		Returns an iterator over all descendants of `root`.
		
		_Uses a non-allocating, iterative traversal._
	**/
	//TODO also iterates over groups?
	public static function descendantsIterator(root:Node):Iterator<Spatial>
	{
		var a = _stackSpatial;
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
	
	/**
		Recomputes world transformations of all nodes along the path from `origin` to root.
	**/
	public static function updateWorldTransformAt(origin:Spatial)
	{
		var top = 0;
		var a = _stackSpatial;
		
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
	public static function updateGeometricState(origin:Node, updateBound = true)
	{
		var a = _stackSpatial;
		a[0] = origin;
		var top = 1, s:Spatial, n:Node;
		while (top != 0)
		{
			s = a[--top];
			a[top] = null;
			
			if (s.mFlags & Spatial.IS_WORLD_XFORM_DIRTY != 0 || (updateBound && s.mFlags & Spatial.IS_WORLD_BOUND_DIRTY != 0))
			{
				s.updateGeometricState(true, updateBound);
				
				//descendants are updated as a "side effect" of the update rooted at this node, so
				//we can safely skip the subtree.
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
	
	public static function updateRenderState(root:Node)
	{
		//update global states
		var a = _stackSpatial;
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
		
		var c = _scratchCoord;
		
		inline function minMax()
		{
			if (c.x < minX) minX = c.x;
			else
			if (c.x > maxX) maxX = c.x;
			
			if (c.y < minY) minY = c.y;
			else
			if (c.y > maxY) maxY = c.y;
		}
		
		var a = _stackSpatial;
		a[0] = root;
		var top = 1, s:Spatial, n:Node, c;
		while (top != 0)
		{
			s = a[--top];
			a[top] = null;
			
			if (s.isVisual())
			{
				as(s, Visual).getBoundingBox(targetSpace, output);
				
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
}