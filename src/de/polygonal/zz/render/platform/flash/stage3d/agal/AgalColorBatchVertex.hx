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
package de.polygonal.zz.render.platform.flash.stage3d.agal;

import flash.display3D.Context3D;

class AgalColorBatchVertex extends AgalColorShader
{
	override function getVertexShader():String
	{
		//|r11 r12  1   tx| vc0
		//|r21 r22  -   ty| vc1
		//| r   g   b   a | vc2
		//| -   -   -   - |
		
		var s = "";
		s += "dp4 op.x, vc0, va0 \n";	//vertex * clipspace row1
		s += "dp4 op.y, vc1, va0 \n";	//vertex * clipspace row2
		s += "mov op.zw, vc0.z \n";		//z = 1, w = 1
		s += "mov v0, va1 \n";			//copy color
		
		return s;
	}
	
	override function getFragmentShader():String
	{
		return "mov oc, v0 \n";
	}
}