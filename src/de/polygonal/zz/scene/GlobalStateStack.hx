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
import de.polygonal.ds.ArrayList;
import de.polygonal.zz.scene.GlobalState;

typedef GlobalStateStackList = ArrayList<ArrayedStack<GlobalState>>;

@:access(de.polygonal.zz.scene.Spatial)
class GlobalStateStack
{
	static var _stacks:GlobalStateStackList;
	static var _tmpStack:ArrayedStack<Spatial>;
	
	inline public static function getStacks():GlobalStateStackList
	{
		if (_stacks == null) initStacks();
		return _stacks;
	}
	
	public static function clearStacks()
	{
		for (i in 0...GlobalState.NUM_STATES)
			_stacks.get(i).clear();
	}
	
	public static function dumpStacks():String
	{
		var s = "";
		for (i in 0...GlobalState.NUM_STATES)
			s += "[$i] => [" + _stacks.get(i).toArray().join("") + "]";
		return s;
	}
	
	public static function propagateStateFromRoot(spatial:Spatial):GlobalStateStackList
	{
		//traverse to root and push states from root to this node
		var stacks = getStacks();
		
		//push parents, then pop and push their state
		var s = _tmpStack, p = spatial;
		s.clear();
		while (p.parent != null)
		{
			s.push(p.parent);
			p = p.parent;
		}
		
		for (i in 0...s.size) s.pop().pushStates(stacks);
		spatial.pushStates(stacks);
		s.clear(true);
		return stacks;
	}
	
	static function initStacks()
	{
		var k = GlobalState.NUM_STATES;
		_stacks = new ArrayList(k);
		for (i in 0...k) _stacks.pushBack(new ArrayedStack<GlobalState>());
		_tmpStack = new ArrayedStack(16);
	}
}