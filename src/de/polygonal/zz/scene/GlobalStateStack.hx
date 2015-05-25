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
import haxe.ds.Vector;

typedef GlobalStateStackList = Vector<ArrayedStack<GlobalState>>;

@:access(de.polygonal.zz.scene.Spatial)
class GlobalStateStack
{
	static var mStacks:GlobalStateStackList;
	static var mTmpVector:Vector<Spatial>;
	
	inline public static function getStacks():GlobalStateStackList
	{
		if (mStacks == null) initStacks();
		return mStacks;
	}
	
	public static function clrStacks()
	{
		for (i in 0...GlobalState.NUM_STATES)
			mStacks[i].clear();
	}
	
	public static function dumpStacks():String
	{
		var s = "";
		for (i in 0...GlobalState.NUM_STATES)
			s += '[$i] => [${mStacks[i].toArray().join("")}]';
		return s;
	}
	
	public static function propagateStateFromRoot(spatial:Spatial):GlobalStateStackList
	{
		var stacks = getStacks();
		
		//traverse to root and push states from root to this node
		//push parents, then pop and push their state
		var v = mTmpVector;
		var k = 0;
		var p = spatial;
		while (p.parent != null)
		{
			v[k++] = p.parent;
			p = p.parent;
		}
		while (k > 0)
		{
			var s = v[--k];
			v[k] = null;
			s.pushStates(stacks);
		}
		spatial.pushStates(stacks);
		
		return stacks;
	}
	
	static function initStacks()
	{
		var k = GlobalState.NUM_STATES;
		mStacks = new Vector<ArrayedStack<GlobalState>>(k);
		for (i in 0...k) mStacks[i] = new ArrayedStack<GlobalState>();
		mTmpVector = new Vector<Spatial>(1024);
	}
}