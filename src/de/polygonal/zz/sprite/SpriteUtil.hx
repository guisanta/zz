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
package de.polygonal.zz.sprite;

import de.polygonal.core.math.Coord2;
import de.polygonal.core.math.Vec3;
import de.polygonal.core.time.Timebase;
import de.polygonal.zz.render.Renderer;
import de.polygonal.zz.scene.*;

/**
	Helper methods to operate on hierarchical sprite structures.
	Most methods are implemented using a non-allocating, iterative traversal.
**/
@:access(de.polygonal.zz.sprite.SpriteBase)
@:access(de.polygonal.zz.scene.Spatial)
class SpriteUtil
{
	static var mStackTickSpatial:Array<Spatial> = [];
	static var mStackSpatial:Array<Spatial> = [];
	static var mTmpCoord = new Coord2f(0, 0);
	
	public static function drawScene(renderer:Renderer, root:SpriteGroup)
	{
		commit(root);
		
		tick(root, Timebase.gameTimeDelta);
		
		var node = root.sgn.asNode();
		
		TreeUtil.updateGeometricState(node, true);
		
		TreeUtil.updateRenderState(node);
		
		renderer.drawScene(node);
	}
	
	/**
		Counts the total number of descendants of root.
	**/
	public static function count(root:SpriteGroup):Int
	{
		var a = mStackSpatial;
		var top = 1, c = 0, s:Spatial;
		a[0] = root.mNode;
		while (top != 0)
		{
			s = a[--top];
			a[top] = null;
			c++;
			if (s.isNode())
			{
				s = s.asNode().child;
				while (s != null)
				{
					a[top++] = s;
					s = s.mSibling;
				}
			}
		}
		return c - 1;
	}
	
	/**
		Creates an iterator over all descendants of root.
		Uses a non-allocating, iterative traversal.
	**/
	public static function descendants(root:SpriteGroup):Iterator<SpriteBase>
	{
		var a = mStackSpatial;
		var top = 0, n:Node, s:Spatial, k:Int, p:Int, c:Spatial;
		
		n = root.mNode;
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
					n = s.asNode();
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
				return SpriteBase.asSpriteBase(s.arbiter);
			}
		}
	}
	
	/**
		Calls tick() on all descendants of root, including root.
		Uses a non-allocating, iterative traversal.
	**/
	public static function tick(root:SpriteGroup, timeDelta:Float)
	{
		var a = mStackTickSpatial;
		a[0] = root.mNode;
		var top = 1, s:Spatial, n:Node, sprite:SpriteBase;
		while (top != 0)
		{
			s = a[--top];
			a[top] = null;
			
			if (s.arbiter == null) continue;
			
			sprite = SpriteBase.asSpriteBase(s.arbiter);
			
			if (sprite.tickable)
				sprite.tick(timeDelta);
			
			if (sprite.mFlags & SpriteGroup.IS_TOPOLOGY_FLATTENED > 0)
			{
				for (c in SpriteBase.asSpriteGroup(sprite).mDescendants)
					c.tick(timeDelta);
				continue;
			}
			
			if (s.isNode())
			{
				n = s.asNode();
				var c = n.child;
				while (c != null)
				{
					a[top++] = c;
					c = c.mSibling;
				}
			}
		}
	}
	
	/**
		Calls commit() on all descendants of `root`, including `root`.
		
		_Uses a non-allocating, iterative traversal._
	**/
	public static function commit(root:SpriteGroup)
	{
		var a = mStackSpatial;
		a[0] = root.mNode;
		var top = 1, s:Spatial, sprite:SpriteBase;
		while (top != 0)
		{
			s = a[--top];
			a[top] = null;
			
			if (s.arbiter == null) continue;
			
			sprite = SpriteBase.asSpriteBase(s.arbiter);
			sprite.commit();
			
			if (sprite.mFlags & SpriteGroup.IS_TOPOLOGY_FLATTENED > 0)
			{
				for (c in cast(sprite, SpriteGroup).mDescendants)
					c.commit();
				continue;
			}
			
			//TODO already called by spritegroup.assemble()?
			if (s.isNode())
			{
				var c = s.asNode().child;
				while (c != null)
				{
					a[top++] = c;
					c = c.mSibling;
				}
			}
		}
	}
	
	/*public static function interpolate(root:SpriteGroup, alpha:Float)
	{
		var a = mStackTickSpatial;
		a[0] = root.mNode;
		var top = 1, s:Spatial, sprite:SpriteBase;
		while (top != 0)
		{
			s = a[--top];
			a[top] = null;
			
			if (s.arbiter == null)
			{
				//L.e('$s arbiter null');
				continue;
			}
			
			sprite = SpriteBase.asSpriteBase(s.arbiter);
			sprite.interpolate(alpha);
			
			if (s.isNode())
			{
				var c = s.asNode().child;
				while (c != null)
				{
					a[top++] = c;
					c = c.mSibling;
				}
			}
		}
	}*/
	
	public static function clearFlags(root:SpriteGroup)
	{
		var a = mStackTickSpatial;
		a[0] = root.mNode;
		var top = 1, s:Spatial, n:Node;
		while (top != 0)
		{
			s = a[--top];
			a[top] = null;
			
			s.mFlags &= ~Spatial.GS_UPDATED;
			
			if (s.isNode())
			{
				n = s.asNode();
				var c = n.child;
				while (c != null)
				{
					a[top++] = c;
					c = c.mSibling;
				}
			}
		}
	}
	
	/**
		Recursive bottom-up deconstruction: Invokes the free() method on all descendants of the given sprite.
	**/
	public static function freeSubtree(sprite:SpriteBase, includeCaller = false)
	{
		if (sprite.isGroup() && !Std.is(sprite, SpriteText))
		{
			var c = SpriteBase.asSpriteGroup(sprite).mNode.child, hook;
			while (c != null)
			{
				hook = c.mSibling;
				freeSubtree(SpriteBase.asSpriteBase(c.arbiter), true);
				c = hook;
			}
		}
		
		if (includeCaller) sprite.free();
	}
}