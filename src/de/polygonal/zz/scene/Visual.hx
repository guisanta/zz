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
import de.polygonal.ds.NativeArray;
import de.polygonal.ds.tools.NativeArrayTools;
import de.polygonal.zz.scene.Bv.BvType;
import de.polygonal.zz.scene.Culler;
import de.polygonal.zz.scene.GlobalState;
import de.polygonal.zz.scene.GlobalStateStack.GlobalStateStackList;
import haxe.EnumFlags;
import de.polygonal.zz.scene.SpatialFlags.*;

using de.polygonal.ds.tools.NativeArrayTools;

/**
	A leaf node in the scene graph hierarchy; the element that is drawn on the screen.
**/
class Visual extends Spatial
{
	public static var getBvTypeFunc:Void->BvType = null;
	
	public var modelBound:Bv;
	
	/**
		An array of all global states that occur on the path from the root node to this node.
	**/
	public var stateList:NativeArray<GlobalState> = null;
	
	/**
		A bit field of all global states that occur on the path from the root node to this node.
	**/
	public var stateFlags(default, null):EnumFlags<GlobalStateType>;
	
	public var type:Int;
	
	function new(?name:String)
	{
		super(name);
		
		mFlags |= IS_VISUAL;
		
		modelBound = createBoundingVolume();
		updateModelBound();
		stateList = NativeArrayTools.alloc(GlobalState.NUM_STATES);
	}
	
	override public function free()
	{
		modelBound.free();
		modelBound = null;
		stateList.nullify();
		stateList = null;
		super.free();
	}
	
	public function updateModelBound()
	{
		mFlags |= IS_MODEL_BOUND_DIRTY;
	}
	
	override public function pick(point:Coord2f, ?result:PickResult):Int
	{
		return throw "override for implementation";
	}
	
	override function updateWorldBound()
	{
		if (worldBoundCurrent) return;
		
		if (mFlags & (IS_WORLD_BOUND_DIRTY | IS_MODEL_BOUND_DIRTY) == 0) return;
		
		//apply world transformation to compute model -> world bounding volume
		modelBound.transformBy(world, worldBound);
		
		mFlags &= ~(IS_WORLD_BOUND_DIRTY | IS_MODEL_BOUND_DIRTY);
		
		super.updateWorldBound();
	}
	
	override function getVisibleSet(culler:Culler, noCull:Bool)
	{
		if (effect != null) culler.insert(this);
	}
	
	override function propagateRenderStateUpdate(stacks:GlobalStateStackList)
	{
		var bits = 0, s, state:GlobalState;
		for (i in 0...stacks.size)
		{
			s = stacks.get(i);
			
			if (s.isEmpty())
			{
				stateList.set(i, null);
				continue;
			}
			
			state = s.top().collapse(s);
			stateList.set(i, state);
			bits |= state.bits;
		}
		
		stateFlags = EnumFlags.ofInt(bits);
	}
	
	override function getBvType():BvType
	{
		if (getBvTypeFunc != null) return getBvTypeFunc();
		return super.getBvType();
	}
}