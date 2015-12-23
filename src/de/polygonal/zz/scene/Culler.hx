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

import de.polygonal.core.math.Vec3;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.ds.Bits;
import de.polygonal.ds.Da;
import de.polygonal.motor.geom.data.Plane2;
import de.polygonal.zz.render.Renderer;

@:access(de.polygonal.zz.scene.Spatial)
class Culler
{
	var mRenderer:Renderer;
	
	var mVisibleSet:Da<Visual>;
	var mPlaneCullState:Int;
	
	var mPlanes:Array<Plane2>;
	var mRectPoints:Array<Vec3>;
	
	public function new(renderer:Renderer)
	{
		mRenderer = renderer;
		mVisibleSet = new Da<Visual>();
		mVisibleSet.reuseIterator = true;
		mPlanes = [for (i in 0...4) new Plane2()];
		mRectPoints = [for (i in 0...4) new Vec3()];
	}
	
	public function free():Void
	{
		mVisibleSet.free();
		mVisibleSet = null;
		mPlanes = null;
	}
	
	inline public function getVisibleSet():Da<Visual> return mVisibleSet;
	
	inline public function getPlaneCullState():Int return mPlaneCullState;
	
	inline public function setPlaneCullState(state:Int) mPlaneCullState = state;
	
	inline public function insert(visible:Visual) mVisibleSet.pushBack(visible);
	
	public function computeVisibleSet(scene:Node, noCull:Bool):Da<Visual>
	{
		assert(scene != null);
		
		mPlaneCullState = Bits.mask(4);
		
		//if the camera has changed, compute a plane for each side of source rectangle in world space
		//plane normals are pointing into the view frustum
		updateClipPlanes();
		
		mVisibleSet.clear();
		scene.onGetVisibleSet(this, noCull);
		
		return mVisibleSet;
	}
	
	/**
		Compare the spatial's world bound against the culling planes.
	**/
	public function isVisible(bound:Bv):Bool
	{
		//"plane-at-a-time culling":
		//for every plane run a "which-side-of-plane query"
		for (i in 0...4)
		{
			var mask = 1 << i;
			var plane = mPlanes[i];
			
			if (mPlaneCullState & mask == 0) continue; //skip disabled plane?
			
			var side = bound.whichSide(plane);
			if (side < 0)
			{
				//object is behind the plane -> cull object.
				return false;
			}
			else
			if (side > 0)
			{
				//object is in front if plane;
				//no need to compare nested bounds against this plane -> disable plane.
				mPlaneCullState &= ~mask;
			}
		}
		
		return true;
	}
	
	function updateClipPlanes()
	{
		//transform side planes to world space
		var c = mRenderer.getCamera();
		
		var s =
		if (c == null)
			mRenderer.getRenderTarget().getSize();
		else
			c.getSize();
		
		//radius of scaled source rectangle
		var rx = s.x / 2;
		var ry = s.y / 2;
		
		var tl = mRectPoints[0];
		var tr = mRectPoints[1];
		var bl = mRectPoints[2];
		var br = mRectPoints[3];
		
		tl.x =-rx;
		tl.y =-ry;
		tr.x = rx;
		tr.y =-ry;
		bl.x =-rx;
		bl.y = ry;
		br.x = rx;
		br.y = ry;
		
		if (c != null)
		{
			var t = c.getInvViewMatrix();
			t.timesVector(tl);
			t.timesVector(tr);
			t.timesVector(bl);
			t.timesVector(br);
		}
		
		//top, bottom, left, right
		mPlanes[0].setFromPoints4(tl.x, tl.y, tr.x, tr.y);
		mPlanes[1].setFromPoints4(br.x, br.y, bl.x, bl.y);
		mPlanes[2].setFromPoints4(bl.x, bl.y, tl.x, tl.y);
		mPlanes[3].setFromPoints4(tr.x, tr.y, br.x, br.y);
	}
}