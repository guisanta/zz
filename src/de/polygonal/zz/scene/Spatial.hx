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

import de.polygonal.core.math.Aabb2;
import de.polygonal.core.math.Coord2.Coord2f;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.core.util.ClassUtil;
import de.polygonal.ds.Hashable;
import de.polygonal.ds.HashKey;
import de.polygonal.zz.controller.ControlledObject;
import de.polygonal.zz.render.effect.Effect;
import de.polygonal.zz.scene.*;
import de.polygonal.zz.scene.Bv.BvType;
import de.polygonal.zz.scene.GlobalStateStack.GlobalStateStackList;

/**
	Abstract base class of the scene graph hierarchy.
**/
@:build(de.polygonal.core.macro.IntConsts.build(
[
	CULL_ALWAYS,
	CULL_NEVER,
	IS_WORLD_XFORM_CURRENT,
	IS_WORLD_BOUND_CURRENT,
	IS_WORLD_XFORM_DIRTY,
	IS_WORLD_BOUND_DIRTY,
	IS_MODEL_BOUND_DIRTY,
	IS_RS_DIRTY,
	IS_NODE,
	IS_VISUAL,
	IS_FREED,
	GS_UPDATED
], true, false))
@:access(de.polygonal.zz.scene.Node)
class Spatial extends ControlledObject implements Hashable
{
	inline public static function as<T>(x:Dynamic, cl:Class<T>):T
	{
		#if flash
		return untyped __as__(x, cl);
		#else
		return cast x;
		#end
	}
	
	public static var DEFAULT_BV_TYPE = BvType.Circle;
	
	public var name:String;
	
	/**
		The parent node or null if this node has no parent.
	**/
	public var parent(default, null):Node;
	
	/**
		Local transformation (relative to parent node).
	**/
	public var local(default, null):Xform;
	
	/**
		World transformation (relative to root node).
	**/
	public var world(default, null):Xform;
	
	/**
		World bounding volume.
	**/
	public var worldBound(default, null):Bv;
	
	/**
		The visual appearance of this node.
	**/
	public var effect:Effect;
	
	/**
		An unique id that identifies this node.
	**/
	@:noCompletion public var key:Int;
	
	var mSibling:Spatial;
	var mFlags:Int;
	var mGlobalState:GlobalStateNode;
	var mArbiter:Dynamic;
	
	function new(?name:String)
	{
		super();
		
		this.name = name;
		key = HashKey.next();
		local = new Xform();
		world = new Xform();
		worldBound = createBoundingVolume();
		mFlags = GS_UPDATED | IS_WORLD_XFORM_DIRTY | IS_WORLD_BOUND_DIRTY | IS_MODEL_BOUND_DIRTY | IS_RS_DIRTY;
	}
	
	/**
		Destroys this object by explicitly nullifying all references for GC'ing used resources.
	**/
	override public function free()
	{
		super.free();
		
		if (parent != null)
			parent.removeChild(this);
		parent = null;
		mSibling = null;
		local.free();
		local = null;
		world.free();
		world = null;
		worldBound = null;
		removeAllGlobalStates();
		effect = null;
		mArbiter = null;
		mFlags = IS_FREED;
	}
	
	public var cullingMode(get_cullingMode, set_cullingMode):CullingMode;
	function get_cullingMode():CullingMode
	{
		return
		if (mFlags & CULL_ALWAYS > 0)
			CullAlways;
		else
		if (mFlags & CULL_NEVER > 0)
			CullNever;
		else
			CullDynamic;
	}
	function set_cullingMode(value:CullingMode):CullingMode
	{
		switch (value)
		{
			case CullDynamic:
				mFlags &= ~(CULL_ALWAYS | CULL_NEVER);
			
			case CullAlways:
				mFlags &= ~CULL_NEVER;
				mFlags |=  CULL_ALWAYS;
			
			case CullNever:
				mFlags |=  CULL_NEVER;
				mFlags &= ~CULL_ALWAYS;
		}
		return value;
	}
	
	inline public function isNode():Bool return mFlags & IS_NODE > 0;
	
	inline public function isVisual():Bool return mFlags & IS_VISUAL > 0;
	
	/**
		In some situations you might need to set the world transform directly and bypass the updateWorldData() mechanism.
		If set to true, the world transform isn't updated.
	**/
	public var worldTransformCurrent(get_worldTransformCurrent, set_worldTransformCurrent):Bool;
	inline function get_worldTransformCurrent():Bool return mFlags & IS_WORLD_XFORM_CURRENT > 0;
	inline function set_worldTransformCurrent(value:Bool):Bool
	{
		value ? mFlags |= IS_WORLD_XFORM_CURRENT : mFlags &= ~IS_WORLD_XFORM_CURRENT;
		return value;
	}
	
	/**
		In some situations you might need to set the world bound directly and bypass the updateWordBound() mechanism.
		If set to true, the world bound isn't updated.
	**/
	public var worldBoundCurrent(get_worldBoundCurrent, set_worldBoundCurrent):Bool;
	inline function get_worldBoundCurrent():Bool return mFlags & IS_WORLD_BOUND_CURRENT > 0;
	inline function set_worldBoundCurrent(value:Bool):Bool
	{
		value ? mFlags |= IS_WORLD_BOUND_CURRENT : mFlags &= ~IS_WORLD_BOUND_CURRENT;
		return value;
	}
	
	function onGetVisibleSet(culler:Culler, noCull:Bool)
	{
		if (mFlags & CULL_ALWAYS > 0) return;
		if (mFlags & CULL_NEVER > 0) noCull = true;
		
		var savePlaneState = culler.getPlaneCullState();
		if (noCull || culler.isVisible(worldBound))
			getVisibleSet(culler, noCull);
		culler.setPlaneCullState(savePlaneState);
	}
	
	function getVisibleSet(culler:Culler, noCull:Bool)
	{
		throw 'override for implementation';
	}
	
	/**
		Returns all nodes intersecting the given `point` in world space coordinates.
	**/
	public function pick(point:Coord2f, ?result:PickResult):Int
	{
		return throw 'override for implementation';
	}
	
	/**
		Computes a bounding box of this node relative to the coordinate system of `targetSpace`.
		Note: Before calling this method make sure world transformations are up-to-date.
	**/
	public function getBoundingBox(targetSpace:Spatial, output:Aabb2):Aabb2
	{
		return throw 'override for implementation';
	}
	
	//{ geometric state
	
	/**
		Recomputes world transformations and world bounding volumes.
		if `intiator` is true, the change in world bounding volume occuring at this node is
		propagated to the root node. Skips computing bounding volumes if `updateBound` is false.
	**/
	public function updateGeometricState(initiator = true, updateBound = true)
	{
		mFlags |= GS_UPDATED;
		
		//propagate transformations: parent => children
		updateWorldData(updateBound);
		
		//propagate world bounding volumes: children => parents
		if (updateBound) updateWorldBound();
		if (initiator && updateBound) propagateBoundToRoot();
	}
	
	/**
		Updates world bounding volumes without recomputing transformations.
		Useful if just the model data changes.
	**/
	public function updateBoundState(updateChildren = true, propagateToRoot = true)
	{
		if (updateChildren)
		{
			if (isNode())
			{
				var node = as(this, Node);
				var c = node.child;
				while (c != null)
				{
					c.updateBoundState(updateChildren, false);
					c = c.mSibling;
				}
			}
		}
		
		updateWorldBound();
		if (propagateToRoot) propagateBoundToRoot();
	}
	
	function updateWorldData(updateBounds:Bool, propagateToChildren:Bool = true)
	{
		if (worldTransformCurrent) return;
		
		mFlags &= ~IS_WORLD_XFORM_DIRTY;
		
		if (worldTransformCurrent) return;
		
		if (parent != null)
			world.setProduct2(parent.world, local); //W' = Wp * L
		else
			world.of(local); //root node
		
		mFlags |= IS_WORLD_BOUND_DIRTY;
	}
	
	function updateWorldBound()
	{
		if (parent != null) parent.mFlags |= Spatial.IS_WORLD_BOUND_DIRTY;
	}
	
	function propagateBoundToRoot()
	{
		if (parent != null)
		{
			parent.updateWorldBound();
			parent.propagateBoundToRoot();
		}
	}
	//}
	
	//{ render state
	
	/**
		Assembles rendering information at this node by traversing the scene graph hierarchy in a depth-first manner.
		
		This function needs only be called at a node whose subtree needs a render state update.
	**/
	public function updateRenderState(stacks:GlobalStateStackList = null)
	{
		var initiator = stacks == null;
		
		if (initiator)
			stacks = GlobalStateStack.propagateStateFromRoot(this);
		else
			pushStates(stacks);
		
		//overriden in node class:
		//propagate the render state update in a recursive traversal of the scene hierarchy
		propagateRenderStateUpdate(stacks);
		
		initiator ? GlobalStateStack.clrStacks() : popStates(stacks);
		
		mFlags &= ~IS_RS_DIRTY;
	}
	
	/**
		Returns the attached render state object of the given `type` or null if no state was found.
	**/
	public function getGlobalState(type:GlobalStateType):GlobalState
	{
		var node = mGlobalState;
		while (node != null)
		{
			if (node.type == type) return node.state;
			node = node.next;
		}
		return null;
	}
	
	/**
		Adds the given `state` object to this node (existing state is replaced by `state`).
	**/
	public function setGlobalState(state:GlobalState)
	{
		assert(state != null);
		
		mFlags |= IS_RS_DIRTY;
		
		if (mGlobalState == null)
		{
			//initialize state list
			mGlobalState = GlobalStateNode.get(state);
			return;
		}
		
		//first try replacing existing state
		var node = mGlobalState, type = state.type;
		while (node != null)
		{
			if (node.type == type)
			{
				node.state = state;
				return;
			}
			node = node.next;
		}
		
		//state does not exist so prepend to list
		node = GlobalStateNode.get(state);
		node.next = mGlobalState;
		mGlobalState = node;
	}
	
	/**
		Finds and removes the state object of the given `type` (if any).
	**/
	public function removeGlobalState(type:GlobalStateType)
	{
		mFlags |= IS_RS_DIRTY;
		var node = mGlobalState, prev = null;
		while (node != null)
		{
			if (node.type == type)
			{
				if (prev != null)
					prev.next = node.next;
				else
					mGlobalState = node.next;
					
				node.next = null;
				GlobalStateNode.put(node);
				return;
			}
			prev = node;
			node = node.next;
		}
	}
	
	public function removeAllGlobalStates()
	{
		mFlags |= IS_RS_DIRTY;
		var node = mGlobalState, next;
		while (node != null)
		{
			next = node.next;
			
			node.next = null;
			GlobalStateNode.put(node);
			
			node = next;
		}
		mGlobalState = null;
	}
	
	public function getRoot():Spatial
	{
		var p = this;
		while (p.parent != null) p = p.parent;
		
		return p;
	}
	
	function propagateRenderStateUpdate(stacks:GlobalStateStackList)
	{
		throw 'override for implementation';
	}
	
	inline function pushStates(stacks:GlobalStateStackList)
	{
		var node = mGlobalState, state;
		while (node != null)
		{
			state = node.state;
			stacks[state.slot].push(state);
			node = node.next;
		}
	}
	
	inline function popStates(stacks:GlobalStateStackList)
	{
		var node = mGlobalState;
		while (node != null)
		{
			stacks[node.state.slot].pop();
			node = node.next;
		}
	}
	//}
	
	function createBoundingVolume():Bv
	{
		return
		switch (getBvType())
		{
			case BvType.Circle: new CircleBv();
			case BvType.Box: new BoxBv();
		}
	}
	
	function getBvType():BvType return DEFAULT_BV_TYPE;
	
	public function toString():String
	{
		return Printf.format('${ClassUtil.getUnqualifiedClassName(this)} name=%s', [name]);
	}
}