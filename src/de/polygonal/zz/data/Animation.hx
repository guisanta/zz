/*
Copyright (c) 2016 Michael Baczynski, http://www.polygonal.de

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
package de.polygonal.zz.data;

/**
	The data (e.g. an image) to be displayed (identified by `value`) and how long the data is to be displayed (`holdTime`).
**/
@:structInit
class AnimationFrame<V>
{
	public var value:V;
	public var holdTime:Float;
	
	public function new(value:V, holdTime:Float)
	{
		this.value = value;
		this.holdTime = holdTime;
	}
}

/**
	A sequence of frames makes an animation.
**/
@:structInit
class Animation<V>
{
	public var name:String;
	public var loop:Bool;
	public var frames:Array<AnimationFrame<V>>;
	
	public function new(name:String, loop:Bool, frames:Array<AnimationFrame<V>>)
	{
		this.name = name;
		this.loop = loop;
		this.frames = frames;
	}
}