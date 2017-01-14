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

import de.polygonal.ds.ArrayedStack;
import de.polygonal.ds.tools.ObjectPool;
import de.polygonal.zz.data.ColorTransform;
import de.polygonal.zz.scene.ColorTransformState;
import de.polygonal.zz.scene.GlobalState;

class ColorTransformState extends GlobalState
{
	static var _pool = new ObjectPool<ColorTransformState>(function() return new ColorTransformState(), 1024);
	
	inline public static function get():ColorTransformState
	{
		var state = _pool.get();
		//state.value = alpha;
		return state;
	}
	
	inline public static function put(state:ColorTransformState)
	{
		_pool.put(state);
	}
	
	public var ct:ColorTransform;
	
	//var mCollapsedState:ColorTransformState;
	
	public function new()
	{
		super(GlobalStateType.AlphaMultiplier);
		
		//this.value = value;
		
		ct = new ColorTransform();
	}
	
	/*override public function collapse(stack:ArrayedStack<GlobalState>):GlobalState
	{
		var combinedValue = 1.;
		for (i in 0...stack.size)
			combinedValue *= stack.get(i).as(ColorTransformState).value;
		
		if (mCollapsedState == null) mCollapsedState = new ColorTransformState(value); //TODO get from pool
		mCollapsedState.value = combinedValue;
		return mCollapsedState;
	}*/
	
	//public function toString():String return '{ColorTransformState, value=$value}';
}

class ColorTransform2
{
   public var alphaMultiplier:Float;
   public var alphaOffset:Float;
   public var blueMultiplier:Float;
   public var blueOffset:Float;
   public var color(get_color, set_color):Int;
   public var greenMultiplier:Float;
   public var greenOffset:Float;
   public var redMultiplier:Float;
   public var redOffset:Float;

   public function new(inRedMultiplier:Float = 1.0, inGreenMultiplier:Float = 1.0, inBlueMultiplier:Float = 1.0, inAlphaMultiplier:Float = 1.0, inRedOffset:Float = 0.0, inGreenOffset:Float = 0.0, inBlueOffset:Float = 0.0, inAlphaOffset:Float = 0.0) 
   {
      redMultiplier = inRedMultiplier;
      greenMultiplier = inGreenMultiplier;
      blueMultiplier = inBlueMultiplier;
      alphaMultiplier = inAlphaMultiplier;
      redOffset = inRedOffset;
      greenOffset = inGreenOffset;
      blueOffset = inBlueOffset;
      alphaOffset = inAlphaOffset;
   }

   public function concat(second:ColorTransform2):Void 
   {
      redMultiplier += second.redMultiplier;
      greenMultiplier += second.greenMultiplier;
      blueMultiplier += second.blueMultiplier;
      alphaMultiplier += second.alphaMultiplier;
   }

   // Getters & Setters
   private function get_color():Int 
   {
      return((Std.int(redOffset) << 16) |(Std.int(greenOffset) << 8) | Std.int(blueOffset));
   }

   private function set_color(value:Int):Int 
   {
      redOffset =(value >> 16) & 0xFF;
      greenOffset =(value >> 8) & 0xFF;
      blueOffset = value & 0xFF;

      redMultiplier = 0;
      greenMultiplier = 0;
      blueMultiplier = 0;

      return color;
   }
}