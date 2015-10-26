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
import de.polygonal.ds.pooling.DynamicObjectPool;
import de.polygonal.zz.scene.AlphaMultiplierState;
import de.polygonal.zz.scene.GlobalState;

class AlphaMultiplierState extends GlobalState
{
	public static var PRESET_OPAQUE(default, null) = new AlphaMultiplierState(1);
	public static var PRESET_TRANSPARENT(default, null) = new AlphaMultiplierState(0);
	
	static var mPool = new DynamicObjectPool<AlphaMultiplierState>(function() return new AlphaMultiplierState(), 1024);
	
	inline public static function get(alpha:Float):AlphaMultiplierState
	{
		var state = mPool.get();
		state.value = alpha;
		return state;
	}
	
	inline public static function put(state:AlphaMultiplierState)
	{
		mPool.put(state);
	}
	
	public var value:Float;
	
	var mCollapsedState:AlphaMultiplierState;
	
	public function new(value:Float = 1.)
	{
		super(GlobalStateType.AlphaMultiplier);
		
		this.value = value;
	}
	
	override public function collapse(stack:ArrayedStack<GlobalState>):GlobalState
	{
		var combinedValue = 1.;
		for (i in 0...stack.size())
			combinedValue *= stack.get(i).as(AlphaMultiplierState).value;
		
		if (mCollapsedState == null) mCollapsedState = new AlphaMultiplierState(value); //TODO get from pool
		mCollapsedState.value = combinedValue;
		return mCollapsedState;
	}
	
	public function toString():String return '{AlphaMultiplierState, value=$value}';
}