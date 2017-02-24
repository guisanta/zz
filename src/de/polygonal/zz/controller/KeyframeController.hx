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
import de.polygonal.core.math.ease.Ease;
import de.polygonal.core.math.ease.EaseFactory;
import de.polygonal.zz.data.Animation;
import de.polygonal.zz.scene.Spatial;
import haxe.ds.StringMap;
import haxe.ds.Vector;
import haxe.EnumFlags;
import de.polygonal.core.math.Mathematics;

@:publicFields
class KeyableParameters
{
	var sx:Null<Float>;
	var sy:Null<Float>;
	var r:Null<Float>;
	var x:Null<Float>;
	var y:Null<Float>;
	var a:Null<Float>;
	var easing:Ease;
	
	function new() {}
}

/**
	The "important" frames of an animation, such as the starting and ending position of an object.
	The contoller then smoothly translates ("tweens") the object from the starting point to the ending point.
**/
typedef KeyframeAnimation = Animation<KeyableParameters>;

interface KeyframeControllerListener
{
	private function onKeyframeUpdate(keyValues:KeyValues):Void;
}

enum KeyValue
{
	ScaleX; ScaleY; Rotate; TranslateX; TranslateY; Alpha;
}

@:publicFields
class KeyValues
{
	var scaleX = 1.;
	var scaleY = 1.;
	var rotation = 0.;
	var translateX = 0.;
	var translateY = 0.;
	var alpha = 1.;
	
	function new() {}
}

/**
	A keyframe controller allows keyframing - the process of assigning a specific parameter value to an object at a specific point in time.
**/
@:access(de.polygonal.zz.scene.Spatial)
@:access(de.polygonal.zz.controller.KeyframeControllerListener)
class KeyframeController extends Controller
{
	static var _dataCache:StringMap<Data> = null;
	
	public var onFinish:Void->Void;
	
	var mListener:KeyframeControllerListener;
	var mLastIndex:Int = 0;
	var mData:Data;
	var mKeyValues = new KeyValues();
	
	public function new()
	{
		super(TYPE);
	}
	
	override public function free() 
	{
		mListener = null;
		onFinish = null;
		
		super.free();
	}
	
	inline public function setListener(listener:KeyframeControllerListener)
	{
		mListener = listener;
	}
	
	public function play(def:KeyframeAnimation, startTime:Float = 0.)
	{
		if (_dataCache == null) _dataCache = new StringMap();
		mData = _dataCache.get(def.name);
		if (mData == null) _dataCache.set(def.name, mData = new Data(def));
		
		mLastIndex = 0;
		repeat = RepeatType.Clamp;
		passedTime = startTime;
		minTime = 0;
		maxTime = mData.length;
		active = true;
		dispose = false;
		
		var v = mKeyValues;
		
		setKeyframe(0);
	}
	
	public function stop()
	{
		onFinish = null;
		markForDisposal();
	}
	
	override function onUpdate(time:Float):Bool
	{
		var controlTime = getControlTime();
		
		var t = mData.times;
		var i0, i1, alpha;
		
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
		
		setKeyframeValues(i0, i1, alpha);
		mListener.onKeyframeUpdate(mKeyValues);
		
		if (time > maxTime && repeat == RepeatType.Clamp)
		{
			if (onFinish != null)
			{
				onFinish();
				onFinish = null;
			}
			
			markForDisposal();
			return false;
		}
		
		return true;
	}
	
	public function setKeyframe(frame:Int)
	{
		setKeyframeValues(frame, frame, 1);
		mListener.onKeyframeUpdate(mKeyValues);
	}
	
	function setKeyframeValues(i0:Int, i1:Int, alpha:Float)
	{
		var p = mData.parameters;
		var v = mKeyValues;
		
		if (i0 != i1)
		{
			alpha = mData.easing[i0].interpolate(alpha);
			
			inline function lerp(chnl:KeyValue)
			{
				var c = chnl.getIndex();
				return Mathematics.lerp(p[i0 * 6 + c], p[i1 * 6 + c], alpha);
			}
			
			var chnls = mData.chnls[i0];
			var f:EnumFlags<KeyValue> = EnumFlags.ofInt(chnls);
			if (f.has(ScaleX)) v.scaleX = lerp(ScaleX);
			if (f.has(ScaleY)) v.scaleY = lerp(ScaleY);
			if (f.has(Rotate)) v.rotation = lerp(Rotate);
			if (f.has(TranslateX)) v.translateX = lerp(TranslateX);
			if (f.has(TranslateY)) v.translateY = lerp(TranslateY);
			if (f.has(Alpha)) v.alpha = lerp(Alpha);
		}
		else
		{
			inline function get(pos:Int, chnl:KeyValue) return p[pos * 6 + chnl.getIndex()];
			
			v.scaleX = get(i1, ScaleX);
			v.scaleY = get(i1, ScaleY);
			v.rotation = get(i1, Rotate);
			v.translateX = get(i1, TranslateX);
			v.translateY = get(i1, TranslateY);
			v.alpha = get(i1, Alpha);
		}
	}
}

@:publicFields
private class Data
{
	var totalFrames(default, null):Int;
	var length(default, null):Float = 0;
	
	var times:Vector<Float>;
	var parameters:Vector<Float>;
	var chnls:Vector<Int>;
	var easing:Vector<Interpolation<Float>>;
	
	public function new(def:KeyframeAnimation)
	{
		totalFrames = def.frames.length;
		
		times = new Vector(totalFrames);
		parameters = new Vector(totalFrames * KeyValue.getConstructors().length); //* #chnls
		chnls = new Vector(totalFrames);
		easing = new Vector(totalFrames);
		
		var linear = EaseFactory.create(Ease.None);
		
		inline function get(pos:Int, chnl:KeyValue) return parameters[pos * 6 + chnl.getIndex()];
		inline function set(pos:Int, chnl:KeyValue, val:Float) parameters[pos * 6 + chnl.getIndex()] = val;
		
		var sx = 1., sy = 1., r = 0., x = 0., y = 0., a = 1.;
		var i = 0, v;
		
		for (frame in def.frames)
		{
			times[i] = length;
			length += frame.holdTime;
			
			v = frame.value;
			
			set(i, ScaleX, sx = v.sx != null ? v.sx : sx);
			set(i, ScaleY, sy = v.sy != null ? v.sy : sy);
			set(i, Rotate, r = v.r != null ? v.r : r);
			set(i, TranslateX, x = v.x != null ? v.x : x);
			set(i, TranslateY, y = v.y != null ? v.y : y);
			set(i, Alpha, a = v.a != null ? v.a : a);
			
			easing[i] =
			if (v.easing != null)
				EaseFactory.create(cast v.easing);
			else
				linear;
			i++;
		}
		
		var i = 0, a, b, c = KeyValue.createAll();
		for (i in 0...totalFrames - 1)
		{
			chnls[i] = 0;
			
			for (j in 0...6)
			{
				a = get(i, c[j]);
				b = get(i + 1, c[j]);
				if (a != b) chnls[i] |= 1 << j;
			}
		}
	}
}