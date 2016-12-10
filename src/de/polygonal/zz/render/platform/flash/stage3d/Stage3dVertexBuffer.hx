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

import de.polygonal.core.math.Vec3;
import flash.display3D.Context3D;
import flash.display3D.Context3DVertexBufferFormat;
import flash.display3D.VertexBuffer3D;
import flash.Vector;

class Stage3dVertexBuffer
{
	static var _vertexBufferFormatLut:Vector<Context3DVertexBufferFormat> = null;
	
	public var numFloatsPerVertex(default, null):Int;
	public var handle(default, null):VertexBuffer3D;
	
	var mContext:Context3D;
	var mBuffer(default, null):Vector<Float>;
	var mAttributes:Vector<Int>;
	var mSize:Int;
	var mDirty:Bool = true;
	var mBufferObjectCapacity:Int = -1;
	
	public function new(context:Context3D, numFloatsPerAttribute:Array<Int>)
	{
		mContext = context;
		
		numFloatsPerVertex = 0;
		mAttributes = new Vector();
		for (i in numFloatsPerAttribute)
		{
			numFloatsPerVertex += i;
			mAttributes.push(i);
		}
		
		if (_vertexBufferFormatLut == null)
		{
			_vertexBufferFormatLut = new Vector<Context3DVertexBufferFormat>(5, true);
			_vertexBufferFormatLut[0] = Context3DVertexBufferFormat.BYTES_4;
			_vertexBufferFormatLut[1] = Context3DVertexBufferFormat.FLOAT_1;
			_vertexBufferFormatLut[2] = Context3DVertexBufferFormat.FLOAT_2;
			_vertexBufferFormatLut[3] = Context3DVertexBufferFormat.FLOAT_3;
			_vertexBufferFormatLut[4] = Context3DVertexBufferFormat.FLOAT_4;
		}
		
		mBuffer = new Vector();
	}
	
	public function free()
	{
		mBuffer = null;
		
		if (handle != null)
		{
			handle.dispose();
			handle = null;
		}
		mContext = null;
		_vertexBufferFormatLut = null;
	}
	
	public function allocate(numVertices:Int)
	{
		mBuffer.fixed = false;
		mBuffer.length = numFloatsPerVertex * numVertices;
		mBuffer.fixed = true;
		
		if (numVertices > mBufferObjectCapacity)
		{
			if (handle != null) handle.dispose();
			handle = mContext.createVertexBuffer(numVertices, numFloatsPerVertex);
			
			mBufferObjectCapacity = numVertices;
			
			#if (verbose == "extra")
			var k = numFloatsPerVertex * numVertices;
			L.d('Allocating vertex buffer: numVertices: $numVertices, numFloatsPerVertex: $numFloatsPerVertex (total of $k floats)', "s3d");
			#end
		}
		
		mSize = 0;
		setDirty();
	}
	
	public function bind()
	{
		var formatLut = _vertexBufferFormatLut;
		var index = 0;
		var bufferOffset = 0;
		for (i in mAttributes)
		{
			#if (verbose == "extra")
			L.d('Binding buffer to index $index, offset=$bufferOffset, size=$i.');
			#end
			
			mContext.setVertexBufferAt(index++, handle, bufferOffset, formatLut[i]);
			bufferOffset += i;
		}
	}
	
	public function unbind()
	{
		for (i in 0...mAttributes.length)
		{
			#if (verbose == "extra")
			L.d('Unbinding buffer from index $i');
			#end
			
			mContext.setVertexBufferAt(i, null);
		}
	}
	
	public function upload()
	{
		var numVertices = Std.int(mBuffer.length / numFloatsPerVertex);
		handle.uploadFromVector(mBuffer, 0, numVertices);
		
		#if (verbose == "extra")
		L.d('Uploading $numVertices vertices.', "s3d");
		#end
	}
	
	inline public function setDirty()
	{
		mDirty = true;
	}
	
	inline public function addFloat1(value:Vec3)
	{
		push(value.x);
	}
	
	inline public function addFloat2(value:Vec3)
	{
		push(value.x);
		push(value.y);
	}
	
	inline public function addFloat3(value:Vec3)
	{
		push(value.x);
		push(value.y);
		push(value.z);
	}
	
	inline public function addFloat4(value:Vec3)
	{
		push(value.x);
		push(value.y);
		push(value.z);
		push(value.w);
	}
	
	inline public function addFloat1f(x:Float)
	{
		push(x);
	}
	
	inline public function addFloat2f(x:Float, y:Float)
	{
		push(x);
		push(y);
	}
	
	inline public function addFloat3f(x:Float, y:Float, z:Float)
	{
		push(x);
		push(y);
		push(z);
	}
	
	inline public function addFloat4f(x:Float, y:Float, z:Float, w:Float)
	{
		push(x);
		push(y);
		push(z);
		push(w);
	}
	
	inline public function setFloat1(offset:Int, value:Vec3)
	{
		mBuffer[offset] = value.x;
	}
	
	inline public function setFloat2(offset:Int, value:Vec3)
	{
		mBuffer[offset + 0] = value.x;
		mBuffer[offset + 1] = value.y;
	}
	
	inline public function setFloat3(offset:Int, value:Vec3)
	{
		mBuffer[offset + 0] = value.x;
		mBuffer[offset + 1] = value.y;
		mBuffer[offset + 2] = value.z;
	}
	
	inline public function setFloat4(offset:Int, value:Vec3)
	{
		mBuffer[offset + 0] = value.x;
		mBuffer[offset + 1] = value.y;
		mBuffer[offset + 2] = value.z;
		mBuffer[offset + 3] = value.w;
	}
	
	inline public function setFloat1f(offset:Int, x:Float)
	{
		mBuffer[offset + 0] = x;
	}
	
	inline public function setFloat2f(offset:Int, x:Float, y:Float)
	{
		mBuffer[offset + 0] = x;
		mBuffer[offset + 1] = y;
	}
	
	public function toString():String
	{
		return '{VertexBuffer: attributes=${mAttributes.join(",")}, #vertices=${Std.int(mSize / numFloatsPerVertex)}}';
	}
	
	inline function push(x:Float) mBuffer[mSize++] = x;
}