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
import de.polygonal.core.math.Mat33;
import de.polygonal.core.math.Mathematics;
import de.polygonal.core.tween.ease.Ease;
import de.polygonal.core.tween.ease.EaseFactory;
import de.polygonal.ds.Vector;
import de.polygonal.zz.data.Animation;
import de.polygonal.zz.scene.Spatial;
import de.polygonal.zz.scene.Xform;
import haxe.ds.StringMap;

using Reflect;

/**
	Keyable Parameters.
**/
typedef KeyframeParameters = { ?sx:Float, ?sy:Float, ?tx:Float, ?ty:Float, ?r:Float, ?a:Float, ?easing:Ease }

/**
	The "important" frames of an animation, such as the starting and ending position of an object.
	The contoller then smoothly translates ("tweens") the object from the starting point to the ending point.
**/
typedef KeyframeAnimation = Animation<KeyframeParameters>;

interface KeyframeControllerListener
{
	private function onKeyFrameUpdate(xform:Xform):Void;
}

/**
	A keyframe controller allows keyframing - the process of assigning a specific parameter value to an object at a specific point in time.
**/
@:access(de.polygonal.zz.scene.Spatial)
@:access(de.polygonal.zz.controller.KeyframeControllerListener)
class KeyframeController extends Controller
{
	static var mDataCache:StringMap<Data> = null;
	
	var mListener:KeyframeControllerListener;
	
	var mLastIndex:Int;
	var mXform:Xform;
	
	var mData:Data;
	
	public function new()
	{
		super();
		mXform = new Xform();
	}
	
	public function play(def:KeyframeAnimation, startTime:Float = 0.)
	{
		if (mDataCache == null) mDataCache = new StringMap();
		mData = mDataCache.get(def.name);
		if (mData == null) mDataCache.set(def.name, mData = new Data(def));
		
		mLastIndex = 0;
		repeat = RepeatType.Clamp;
		passedTime = 0;
		minTime = 0;
		maxTime = mData.length;
		active = true;
		dispose = false;
	}
	
	inline public function setListener(listener:KeyframeControllerListener)
	{
		mListener = listener;
	}
	 
	override function onUpdate(time:Float):Bool
	{
		var controlTime = getControlTime();
		
		var t = mData.times;
		var i0, i1;
		var alpha;
		
		if (controlTime <= t[0])
		{
			alpha = 0.;
			i0 = i1 = mLastIndex = 0;
		}
		else
		if (controlTime >= t[mData.totalFrames - 1])
		{
			alpha = 0.;
			i0 = i1 = mLastIndex = mData.totalFrames - 1;
		}
		else
		{
			var nextIndex;
			if (controlTime > t[mLastIndex])
			{
				nextIndex = mLastIndex + 1;
				while (controlTime >= t[nextIndex])
				{
					mLastIndex = nextIndex;
					++nextIndex;
				}
				
				i0 = mLastIndex;
				i1 = nextIndex;
				alpha = (controlTime - t[i0]) / (t[i1] - t[i0]);
			}
			else
			if (controlTime < t[mLastIndex])
			{
				nextIndex = mLastIndex - 1;
				while (controlTime <= t[nextIndex])
				{
					mLastIndex = nextIndex;
					--nextIndex;
				}
				
				i0 = nextIndex;
				i1 = mLastIndex;
				alpha = (controlTime - t[i0]) / (t[i1] - t[i0]);
			}
			else
			{
				alpha = 0.;
				i0 = i1 = mLastIndex;
			}
		}
		
		var parameters = mData.parameters;
		alpha = mData.easing[i0].interpolate(alpha);
		
		inline function lerp(channel:Int):Float
			return M.lerp(parameters[i0 * 6 + channel], parameters[i1 * 6 + channel], alpha);
		
		//TODO only lerp active channels
		/*if (i0 == mLastIndex)
		{
			var channels = mData.channels[i0];
			
			if (channels & (1 << Data.CHANNEL_SCALE_X) == 0) trace('skip sx');
			if (channels & (1 << Data.CHANNEL_SCALE_Y) == 0) trace('skip sy');
			if (channels & (1 << Data.CHANNEL_ROTATE) == 0) trace('skip r');
			if (channels & (1 << Data.CHANNEL_TRANSLATE_X) == 0) trace('skip tx');
			if (channels & (1 << Data.CHANNEL_TRANSLATE_Y) == 0) trace('skip ty');
			if (channels & (1 << Data.CHANNEL_ALPHA) == 0) trace('skip alpha');
		}*/
			
		var scaleX = lerp(0);
		var scaleY = lerp(1);
		var rotate = lerp(2);
		var translateX = lerp(3);
		var translateY = lerp(4);
		var alpha = lerp(5);
		
		mXform.setTranslate2(translateX, translateY);
		mXform.setScale2(scaleX, scaleY);
		var mat = new Mat33(); //TODO optimize
		mat.setRotate2(rotate * M.DEG_RAD);
		mXform.setRotate(mat);
		
		if (mListener != null)
			mListener.onKeyFrameUpdate(mXform);
		else
		{
			var local = cast(getObject(), Spatial).local;
			//local.setTranslate2(translateX, translateY);
			//local.setScale2
			//local.setRotate
		}
		
		return true;
	}
	
	function lerpDegrees(start:Float, end:Float, amount:Float):Float
    {
        var difference = Math.abs(end - start);
        if (difference > 180)
        {
            if (end > start)
                start += 360;
            else
                end += 360;
        }

        var value = (start + ((end - start) * amount));

        var rangeZero = 360;

		return (value >= 0 && value <= 360) ? value : (value % rangeZero);
    }
}

@:build(de.polygonal.core.macro.IntConsts.build(
[
	CHANNEL_SCALE_X,
	CHANNEL_SCALE_Y,
	CHANNEL_ROTATE,
	CHANNEL_TRANSLATE_X,
	CHANNEL_TRANSLATE_Y,
	CHANNEL_ALPHA
], false, true))
private class Data
{
	public var totalFrames(default, null):Int;
	public var length(default, null):Float = 0;
	
	public var times:Vector<Float>;
	public var parameters:Vector<Float>;
	public var channels:Vector<Int>;
	public var easing:Vector<Interpolation<Float>>;
	
	public function new(def:KeyframeAnimation)
	{
		totalFrames = def.frames.length;
		
		times = new Vector<Float>(totalFrames);
		parameters = new Vector<Float>(totalFrames * 6); //* #channels
		channels = new Vector<Int>(totalFrames);
		easing = new Vector<Interpolation<Float>>(totalFrames);
		
		var linear = EaseFactory.create(Ease.None);
		
		inline function getp(i:Int, channel:Int) return parameters[i * 6 + channel];
		inline function setp(i:Int, channel:Int, x:Float) parameters[i * 6 + channel] = x;
		
		var i = 0;
		for (frame in def.frames)
		{
			times[i] = length;
			length += frame.holdTime;
			var v = frame.value;
			
			setp(i, Data.CHANNEL_SCALE_X, v.hasField("sx") ? v.sx : 1.);
			setp(i, Data.CHANNEL_SCALE_Y, v.hasField("sy") ? v.sy : 1.);
			setp(i, Data.CHANNEL_ROTATE, v.hasField("r") ? v.r : 0.);
			setp(i, Data.CHANNEL_TRANSLATE_X, v.hasField("tx") ? v.tx : 0.);
			setp(i, Data.CHANNEL_TRANSLATE_Y, v.hasField("ty") ? v.ty : 0.);
			setp(i, Data.CHANNEL_ALPHA, v.hasField("a") ? v.a : 1.);
			
			easing[i] =
			if (v.hasField("easing"))
				EaseFactory.create(v.easing);
			else
				linear;
			i++;
		}
		
		var i = 0;
		for (i in 0...totalFrames - 1)
		{
			channels[i] = 0;
			for (j in 0...6)
			{
				if (getp(i, j) != getp(i + 1, j))
				{
					var a = getp(i, j);
					var b = getp(i + 1, j);
					//trace('set active channel $j on keyframe $i ($a -> $b)');
					channels[i] |= 1 << j;
				}
			}
		}
	}
}