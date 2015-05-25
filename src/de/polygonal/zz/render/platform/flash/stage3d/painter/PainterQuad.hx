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
package de.polygonal.zz.render.platform.flash.stage3d.painter;

import de.polygonal.zz.render.platform.flash.stage3d.Stage3dIndexBuffer;
import de.polygonal.zz.render.platform.flash.stage3d.Stage3dVertexBuffer;

class PainterQuad extends Painter
{
	function initVertexBuffer(numQuads:Int, numFloatsPerAttribute:Array<Int>)
	{
		var b = mVertexBuffer = new Stage3dVertexBuffer(mContext, numFloatsPerAttribute);
		b.allocate(numQuads * 4);
		for (i in 0...numQuads)
		{
			b.addFloat2f(0, 0);
			b.addFloat2f(1, 0);
			b.addFloat2f(1, 1);
			b.addFloat2f(0, 1);
		}
		b.upload();
	}
	
	function initIndexBuffer(numQuads:Int)
	{
		var b = mIndexBuffer = new Stage3dIndexBuffer(mContext);
		for (i in 0...numQuads)
		{
			var offset = i * 4;
			
			b.add(offset + 0);
			b.add(offset + 1);
			b.add(offset + 2);
			
			b.add(offset + 0);
			b.add(offset + 2);
			b.add(offset + 3);
		}
		b.upload();
	}
}