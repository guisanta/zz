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

import de.polygonal.core.math.Coord2.Coord2f;
import de.polygonal.ds.Vector;
import de.polygonal.zz.scene.Bv.BvType;
import de.polygonal.zz.scene.Culler;
import de.polygonal.zz.scene.GlobalState;
import de.polygonal.zz.scene.GlobalStateStack.GlobalStateStackList;
import haxe.EnumFlags;

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
	public var stateList:Vector<GlobalState> = null;
	
	/**
		A bit field of all global states that occur on the path from the root node to this node.
	**/
	public var stateFlags(default, null):EnumFlags<GlobalStateType>;
	
	public var type:Int;
	
	function new(?name:String)
	{
		super(name);
		
		mFlags |= Spatial.IS_VISUAL;
		
		modelBound = createBoundingVolume();
		updateModelBound();
		
		var k = GlobalState.NUM_STATES;
		stateList = new Vector<GlobalState>(k);
		for (i in 0...k) stateList[i] = null;
	}
	
	override public function free()
	{
		modelBound = null;
		stateList = null;
		super.free();
	}
	
	public function updateModelBound()
	{
		mFlags |= Spatial.IS_MODEL_BOUND_DIRTY;
	}
	
	override public function pick(point:Coord2f, ?result:PickResult):Int
	{
		return throw 'override for implementation';
	}
	
	override function updateWorldBound()
	{
		if (worldBoundCurrent) return;
		
		if (mFlags & (Spatial.IS_WORLD_BOUND_DIRTY | Spatial.IS_MODEL_BOUND_DIRTY) == 0) return;
		
		#if profile
		SceneStats.numBvUpdates++;
		#end
		
		//apply world transformation to compute model -> world bounding volume
		modelBound.transformBy(world, worldBound);
		
		mFlags &= ~(Spatial.IS_WORLD_BOUND_DIRTY | Spatial.IS_MODEL_BOUND_DIRTY);
		
		super.updateWorldBound();
	}
	
	override function getVisibleSet(culler:Culler, noCull:Bool)
	{
		if (effect != null) culler.insert(this);
	}
	
	override function propagateRenderStateUpdate(stacks:GlobalStateStackList)
	{
		var bits = 0;
		var i = 0, k = stacks.length, stack, state:GlobalState;
		while (i < k)
		{
			var stack = stacks[i];
			if (stack.isEmpty())
			{
				stateList[i++] = null;
				continue;
			}
			
			state = stack.top().collapse(stack);
			stateList[i++] = state;
			bits |= state.bits;
		}
		
		stateFlags = EnumFlags.ofInt(bits);
	}
	
	/*override function propagateRenderStateUpdate(stacks:GlobalStateStackList)
	{
		//render state at leaf node represents all global stateList from root to leaf
		//copy stateList: put stack contents into local linked list
		stateFlags = 0;
		
		var i = 0, k = stacks.length, stack, state:GlobalState = null, node;
		
		if (stateList == null)
		{
			//initialize linked list
			while (i < k)
			{
				stack = stacks[i++];
				if (!stack.isEmpty())
				{
					state = stack.top().collapse(stack);
					stateList = GlobalStateNode.get(state);
					stateFlags |= state.bit;
					break;
				}
			}
			
			//append remaining stateList
			node = stateList;
			while (i < k)
			{
				stack = stacks[i++];
				if (!stack.isEmpty())
				{
					state = stack.top().collapse(stack);
					node.next = GlobalStateNode.get(state);
					stateFlags |= state.bit;
					node = node.next;
				}
			}
		}
		else
		{
			//overwrite existing nodes before creating new ones
			node = stateList;
			
			var prev:GlobalStateNode = null;
			while (i < k)
			{
				stack = stacks[i++];
				if (stack.isEmpty()) continue;
				state = stack.top().collapse(stack);
				
				if (node == null)
					prev.next = node = GlobalStateNode.get(state); //append new node
				else
					node.state = state; //reuse exising node
				
				stateFlags |= state.bit;
				
				prev = node;
				node = node.next;
			}
			
			//trim superfluous nodes
			if (node != null)
			{
				if (prev != null) prev.next = null;
				
				while (node != null)
				{
					var next = node.next;
					GlobalStateNode.put(node);
					node.next = null;
					node = next;
				}
			}
			
			//empty list
			if (stateList.state == null) stateList = null;
		}
	}*/
	
	override function getBvType():BvType
	{
		if (getBvTypeFunc != null) return getBvTypeFunc();
		return super.getBvType();
	}
}