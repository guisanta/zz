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
package de.polygonal.zz.render.platform.flash.stage3d;

import de.polygonal.core.util.Assert.assert;
import flash.display3D.Context3D;
import flash.display3D.IndexBuffer3D;
import flash.Vector;

class Stage3dIndexBuffer
{
	public var numIndices(default, null):Int;
	
	public var numTriangles(get_numTriangles, never):Int;
	function get_numTriangles():Int
	{
		return Std.int(numIndices / 3);
	}
	
	public var handle(default, null):IndexBuffer3D;
	
	var mContext:Context3D;
	var mBuffer:Vector<UInt>;
	var mCapacity:Int = -1;
	
	public function new(context:Context3D, capacity:Int = -1)
	{
		mContext = context;
		mCapacity = capacity;
		
		if (capacity == -1)
			mBuffer = new Vector<UInt>();
		else
			mBuffer = new Vector<UInt>(capacity, true);
		numIndices = 0;
	}
	
	public function free()
	{
		if (handle != null)
		{
			handle.dispose();
			handle = null;
		}
		
		mBuffer = null;
		mContext = null;
	}
	
	inline public function clear()
	{
		numIndices = 0;
	}
	
	inline public function add(i:Int)
	{
		assert(mBuffer != null);
		assert(numIndices <= 0xffff);
		
		#if debug
		if (mCapacity != -1) assert(numIndices < mCapacity);
		#end
		
		mBuffer[numIndices++] = i;
	}
	
	public function upload(count = -1)
	{
		if (count == -1) count = numIndices;
		
		if (handle != null) handle.dispose();
		handle = mContext.createIndexBuffer(count);
		handle.uploadFromVector(mBuffer, 0, count);
		
		#if verbose
		L.d('uploading $count indices.', "s3d");
		#end
	}
	
	public function toString():String
	{
		return '{IndexBuffer: #indices=$numIndices, #triangles=$numTriangles}';
	}
}