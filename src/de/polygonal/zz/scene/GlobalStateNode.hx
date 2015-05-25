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

import de.polygonal.ds.Vector;

class GlobalStateNode
{
	//TODO use pool from ds lib
	inline static var POOL_CAPACITY = 4096;
	
	static var mPool:Vector<GlobalStateNode>;
	static var mSize:Int = 0;
	
	inline public static function get(state:GlobalState):GlobalStateNode
	{
		if (mPool == null)
			mPool = new Vector<GlobalStateNode>(POOL_CAPACITY);
		
		if (mSize > 0)
		{
			var node = mPool[--mSize];
			mPool[mSize] = null;
			node.state = state;
			node.type = state.type;
			return node;
		}
		else
			return new GlobalStateNode(state);
	}
	
	inline public static function put(node:GlobalStateNode)
	{
		node.state = null;
		if (mSize < POOL_CAPACITY) mPool[mSize++] = node;
	}
	
	public var state:GlobalState;
	
	public var type:GlobalStateType;
	
	public var next:GlobalStateNode;
		
	public function new(state:GlobalState)
	{
		this.state = state;
		this.type = state.type;
	}
	
	public function toString():String
	{
		var a = [];
		var n = this;
		while (n != null)
		{
			a.push(Std.string(n.state));
			n = n.next;
		}
		return "[" + a.join(",") + "]";
	}
}