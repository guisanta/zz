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
import de.polygonal.ds.ArrayedStack;
import de.polygonal.zz.scene.Spatial.as;

/**
	Scene graph helper functions.
**/
@:access(de.polygonal.zz.scene.Spatial)
class TreeTools
{
	static var _tmpCoord = new Coord2f();
	static var _spatialStack1 = new ArrayedStack<Spatial>();
	static var _spatialStack2 = new ArrayedStack<Spatial>();
	
	public static function gc()
	{
		_spatialStack1.clear(true);
		_spatialStack2.clear(true);
	}
	
	/**
		Returns an iterator over all descendants of `root`.
		@param ordered if true, nodes are traversed in the correct draw order.
	**/
	public static function descendantsIterator(root:Node, ordered:Bool = false):Iterator<Spatial>
	{
		if (ordered)
		{
			var a = [], top = 0;
			
			inline function pushChildren(x:Node)
			{
				var k = x.numChildren;
				var p = top + k;
				var c = x.child;
				while (c != null)
				{
					a[p++] = c;
					c = c.mSibling;
				}
				for (i in 0...k)
					a[top++] = a[--p];
			}
			
			pushChildren(root);
			
			return
			{
				hasNext: function()
				{
					return top > 0;
				},
				next: function()
				{
					var s = a[--top];
					if (s.isNode())
						pushChildren(cast s);
					return s;
				}
			}
		}
		else
		{
			var a = [], top = 0;
			
			inline function pushChildren(x:Node)
			{
				var c = x.child;
				while (c != null)
				{
					a[top++] = c;
					c = c.mSibling;
				}
			}
			
			pushChildren(root);
			
			return
			{
				hasNext: function()
				{
					return top > 0;
				},
				next: function()
				{
					var s = a[--top];
					if (s.isNode())
						pushChildren(cast s);
					return s;
				}
			}
		}
	}
	
	/**
		Stores all descendants of `root`, including `root` in `output`.
		@param ordered if true, nodes are stored in the correct draw order.
	**/
	public static function descendants(root:Node, output:ArrayList<Spatial>, ordered:Bool = false)
	{
		var a = _spatialStack1;
		a.clear();
		a.push(root);
		
		var s:Spatial, n, c;
		
		if (ordered)
		{
			var b = _spatialStack2;
			b.clear();
			while (a.size > 0)
			{
				s = a.pop();
				output.pushBack(s);
				if (s.isNode())
				{
					n = as(s, Node);
					c = n.child;
					while (c != null)
					{
						b.push(c);
						c = c.mSibling;
					}
					for (i in 0...b.size) a.push(b.pop());
				}
			}
		}
		else
		{
			while (a.size > 0)
			{
				s = a.pop();
				output.pushBack(s);
				if (s.isNode())
				{
					n = as(s, Node);
					c = n.child;
					while (c != null)
					{
						a.push(c);
						c = c.mSibling;
					}
				}
			}
		}
	}
	
	/**
		Returns the total number of descendants + 1.
	**/
	public static function size(root:Node):Int
	{
		var s = _spatialStack1, k = 0, n, c;
		s.clear();
		s.push(root);
		while (s.size > 0)
		{
			n = as(s.pop(), Node);
			k += n.numChildren;
			if (n.numChildrenOfTypeNode > 0)
			{
				c = n.child;
				while (c != null)
				{
					if (c.isNode()) s.push(as(c, Node));
					c = c.mSibling;
				}
			}
		}
		return k + 1;
	}
	
	/**
		Recomputes world transformations of all nodes along the path from `origin` to root.
	**/
	public static function updateWorldTransformAt(origin:Spatial)
	{
		var a = _spatialStack1, p, c;
		a.clear();
		
		p = origin;
		while (p != null)
		{
			a.push(p);
			p = p.parent;
		}
		
		p = a.pop();
		p.mFlags &= ~Spatial.IS_WORLD_XFORM_DIRTY;
		p.world.of(p.local);
		while (a.size > 0)
		{
			c = a.pop();
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
		var a = _spatialStack1, s, n, c;
		a.clear();
		a.push(root);
		
		var mask = Spatial.IS_WORLD_XFORM_DIRTY;
		if (updateBound) mask |= Spatial.IS_WORLD_BOUND_DIRTY;
		
		while (a.size > 0)
		{
			s = a.pop();
			
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
				c = n.child;
				while (c != null)
				{
					a.push(c);
					c = c.mSibling;
				}
			}
		}
	}
	
	/**
		Recomputers render state information for `root` and all descendants of `root`.
		
		_This method uses an efficient iterative algorithm that does minimal work._
	**/
	public static function updateRenderState(root:Node)
	{
		var a = _spatialStack1, s, n, c;
		a.clear();
		a.push(root);
		
		while (a.size > 0)
		{
			s = a.pop();
			
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
				c = n.child;
				while (c != null)
				{
					a.push(c);
					c = c.mSibling;
				}
			}
		}
	}
	
	/**
		Stores all leaf nodes with cullingMode != CullAlways in `output`.
	**/
	public static function getVisibleLeafs(scene:Node, output:ArrayList<Visual>)
	{
		var s, n, c;
		var a = _spatialStack1;
		var b = _spatialStack2;
		a.clear();
		a.push(scene);
		while (a.size > 0)
		{
			s = a.pop();
			
			if (s.mFlags & Spatial.CULL_ALWAYS > 0) continue;
			
			if (s.isVisual())
			{
				if (s.effect != null)
					b.push(s);
			}
			else
			if (s.isNode())
			{
				n = as(s, Node);
				c = n.child;
				while (c != null)
				{
					a.push(c);
					c = c.mSibling;
				}
			}
		}
		
		//correct draw order (reverse)
		output.clear();
		output.reserve(output.size + b.size);
		for (i in 0...b.size) output.unsafePushBack(as(b.pop(), Visual));
	}
	
	/**
		Computes the bounding box of `root` relative to `targetSpace`.
		Note: Before calling this method make sure world transformations are up-to-date.
	**/
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
		
		var a = _spatialStack1;
		a.clear();
		a.push(root);
		var s:Spatial, n:Node, c;
		while (a.size > 0)
		{
			s = a.pop();
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
					a.push(c);
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
	
	/**
		Transforms `input` defined in the coordinate system of `sourceSpace` to `targetSpace`, storing the result in `output`.
	**/
	public static function transformBoundingBox(sourceSpace:Spatial, targetSpace:Spatial, input:Aabb2, output:Aabb2):Aabb2
	{
		var iMinX = input.minX;
		var iMinY = input.minY;
		var iMaxX = input.maxX;
		var iMaxY = input.maxY;
		
		var oMinX = Limits.FLOAT_MAX;
		var oMinY = Limits.FLOAT_MAX;
		var oMaxX = Limits.FLOAT_MIN;
		var oMaxY = Limits.FLOAT_MIN;
		
		var c = _tmpCoord;
		
		inline function minMax(c)
		{
			if (c.x < oMinX) oMinX = c.x;
			if (c.x > oMaxX) oMaxX = c.x;
			if (c.y < oMinY) oMinY = c.y;
			if (c.y > oMaxY) oMaxY = c.y;
		}
		
		if (targetSpace == sourceSpace)
			output.of(input);
		else
		if (targetSpace == sourceSpace.parent) //targetSpace is parent of this
		{
			var t = sourceSpace.local;
			c.set(iMinX, iMinX); t.applyForward2(c, c); minMax(c);
			c.set(iMaxX, iMinY); t.applyForward2(c, c); minMax(c);
			c.set(iMaxX, iMaxY); t.applyForward2(c, c); minMax(c);
			c.set(iMinX, iMaxY); t.applyForward2(c, c); minMax(c);
		}
		else
		if (targetSpace.parent == null) //targetSpace is root
		{
			var t = sourceSpace.world;
			c.set(iMinX, iMinX); t.applyForward2(c, c); minMax(c);
			c.set(iMaxX, iMinY); t.applyForward2(c, c); minMax(c);
			c.set(iMaxX, iMaxY); t.applyForward2(c, c); minMax(c);
			c.set(iMinX, iMaxY); t.applyForward2(c, c); minMax(c);
		}
		else
		{
			var t = sourceSpace.world;
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
	
	/**
		Pretty-prints the scene graph hierarchy starting at `root`.
	**/
	public static function print(root:Node, leafs:Bool = true, inset:String = ""):String
	{
		var s = inset + root.name + "\n";
		var c = root.child;
		while (c != null)
		{
			if (Std.is(c, Node))
			{
				s += print(cast c, leafs, inset + "\t");
				c = c.mSibling;
				continue;
			}
			if (leafs)
				s += inset + "\t" + c.name + "\n";
			c = c.mSibling;
		}
		return s;
	}
}