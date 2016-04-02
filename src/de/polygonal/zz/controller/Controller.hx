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

Geometric Tools, LLC
Copyright (c) 1998-2012
Distributed under the Boost Software License, Version 1.0.
http://www.boost.org/LICENSE_1_0.txt
http://www.geometrictools.com/License/Boost/LICENSE_1_0.txt
*/
package de.polygonal.zz.controller;

import de.polygonal.core.util.Assert.assert;
import de.polygonal.core.math.Mathematics;

@:autoBuild(de.polygonal.zz.controller.ControllerType.build())
class Controller
{
	public static var COUNT = 0;
	public static var ACTIVE_COUNT = 0;
	public static var DISPOSE_TIMEOUT = 10;
	
	public var repeat:RepeatType;
	public var minTime:Float = 0;
	public var maxTime:Float = 0;
	public var phase:Float = 0;
	public var frequency:Float = 1;
	public var passedTime:Float = 0;
	public var dispose:Bool;
	
	public var type:Int;
	public var next:Controller;
	
	var mActive = false;
	public var active(get, set):Bool;
	inline function get_active():Bool return mActive;
	inline function set_active(value:Bool):Bool
	{
		if (mActive != value)
			value ? ACTIVE_COUNT++ : ACTIVE_COUNT--;
		return mActive = value;
	}
	
	var mObject:ControlledObject;
	
	function new()
	{
		repeat = RepeatType.Clamp;
		type = Reflect.field(Type.getClass(this), "TYPE");
		COUNT++;
	}
	
	public function free()
	{
		if (mObject != null)
		{
			mObject.detach(this);
			mObject = null;
		}
		repeat = null;
		assert(next == null);
		type = -1;
		COUNT--;
	}
	
	inline public function getObject():ControlledObject
	{
		return mObject;
	}
	
	inline public function setObject(object:ControlledObject)
	{
		mObject = object;
	}
	
	public function markForDisposal()
	{
		dispose = true;
		active = false;
		passedTime = 0;
		maxTime = DISPOSE_TIMEOUT;
	}
	
	inline public function as<T:Controller>(cl:Class<T>):T
	{
		#if flash
		return untyped __as__(this, cl);
		#else
		return cast this;
		#end
	}
	
	inline public function update(dt:Float):Bool
	{
		if (active)
		{
			passedTime += dt * frequency;
			if (mObject == null) //controller was freed
				return false;
			else
				return onUpdate(passedTime);
		}
		else
		if (dispose)
		{
			passedTime += dt;
			if (passedTime > DISPOSE_TIMEOUT) free();
			return true;
		}
		else
			return false;
	}
	
	function onUpdate(time:Float):Bool
	{
		return throw "override for implementation";
	}
	
	function getControlTime():Float
	{
		var controlTime = passedTime + phase;
		if (repeat == RepeatType.Clamp)
			return M.fclamp(controlTime, minTime, maxTime);
		
		var timeRange = maxTime - minTime;
		if (timeRange > 0)
		{
			var multiples = (controlTime - minTime) / timeRange;
			var integerTime = M.floor(multiples);
			var fractionTime = multiples - integerTime;
			
			if (repeat == RepeatType.Wrap)
				return minTime + fractionTime * timeRange;
			
			if (M.isEven(integerTime))
				return minTime + fractionTime * timeRange; //go forward in time
			else
				return maxTime - fractionTime * timeRange; //go backward in time
		}
		
		//the minimum and maximum times are the same, so return the minimum.
		return minTime;
	}
}