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

import de.polygonal.ds.ArrayedStack;
import de.polygonal.zz.scene.GlobalState;

/**
	A global state attached to an interior node in a scene graph affects all leaf nodes in the
	subtree rooted at that node.
**/
@:build(de.polygonal.core.macro.IntConsts.build(
[
	STATE_ALPHA_MULTIPLIER,
	STATE_ALPHA_BLEND,
	STATE_COLOR_TRANSFORM,
	MAX
], false, true))
class GlobalState
{
	public static var NUM_STATES = Type.getEnumConstructs(GlobalStateType).length;
	
	public var type(default, null):GlobalStateType;
	
	public var slot(default, null):Int;
	
	public var bits(default, null):Int;
	
	public function new(type:GlobalStateType)
	{
		this.type = type;
		slot = type.getIndex();
		bits = 1 << slot;
	}
	
	inline public function equals(other:GlobalState):Bool
	{
		return bits == other.bits;
	}
	
	inline public function as<T:GlobalState>(state:Class<T>):T
	{
		#if flash
		return untyped __as__(this, state);
		#else
		return cast this;
		#end
	}
	
	public function collapse(stack:ArrayedStack<GlobalState>):GlobalState
	{
		return throw "override for implementation";
	}
}