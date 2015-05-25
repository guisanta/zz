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
package de.polygonal.zz.controller;

import de.polygonal.core.math.Interpolation;
import de.polygonal.core.math.Mathematics.M;
import de.polygonal.core.tween.ease.Ease;
import de.polygonal.core.tween.ease.EaseFactory;
import de.polygonal.zz.controller.Controller;
import de.polygonal.zz.controller.RepeatType;

interface TweenControllerListener
{
	private function onTweenUpdate(id:Int, value:Float):Void;
	
	private function onTweenFinish(id:Int):Void;
}

@:access(de.polygonal.zz.controller.TweenControllerListener)
class TweenController extends Controller
{
	static var mCounter = 0;
	
	public var id(default, null):Int;
	
	var mSrcVal:Float;
	var mDstVal:Float;
	var mInterpolation:Interpolation<Float>;
	var mListener:TweenControllerListener;
	
	public function new()
	{
		super();
	}
	
	inline public function setListener(listener:TweenControllerListener)
	{
		mListener = listener;
	}
	
	override public function free()
	{
		mInterpolation = null;
		mListener = null;
		super.free();
	}
	
	public function tween(srcVal:Float, dstVal:Float, duration:Float, ease:Ease):Int
	{
		mSrcVal = srcVal;
		mDstVal = dstVal;
		passedTime = 0;
		minTime = 0;
		maxTime = duration;
		mInterpolation = EaseFactory.create(ease);
		
		if (!active) id = mCounter++;
		active = true;
		dispose = false;
		return id;
	}
	
	public function stop()
	{
		disposeAfterTimeout();
	}
	
	override function onUpdate(time:Float):Bool
	{
		if (time >= maxTime && repeat == RepeatType.Clamp)
		{
			mListener.onTweenUpdate(id, mDstVal);
			mListener.onTweenFinish(id);
			disposeAfterTimeout();
			return false;
		}
		
		var controlTime = getControlTime();
		var alpha = (controlTime - minTime) / (maxTime - minTime); //[0,1]
		var value = M.lerp(mSrcVal, mDstVal, mInterpolation.interpolate(alpha));
		mListener.onTweenUpdate(id, value);
		return true;
	}
}