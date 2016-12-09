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

@:access(de.polygonal.zz.controller.Controller)
class ControlledObject
{
	public var controllers(default, null):Controller;
	
	public var controllersEnabled:Bool = true;
	
	function new()
	{
		controllers = null;
	}
	
	public function free()
	{
		var c = controllers;
		while (c != null)
		{
			var next = c.next;
			c.free();
			c = next;
		}
		
		assert(controllers == null);
	}
	
	public function attach(controller:Controller)
	{
		#if debug
		if (controllers != null)
		{
			var n = controllers;
			while (n != null)
			{
				assert(n != controller);
				n = n.next;
			}
		}
		#end
		
		if (controllers == null) //head?
		{
			assert(controller.next == null);
			controllers = controller;
		}
		else
		{
			//prepend
			controller.next = controllers;
			controllers = controller;
		}
		
		controller.setObject(this);
	}
	
	public function detach(controller:Controller)
	{
		#if debug
		assert(controllers != null);
		var exists = false;
		var n = controllers;
		while (n != null)
		{
			if (n == controller)
			{
				exists = true;
				break;
			}
			n = n.next;
		}
		assert(exists);
		#end
		
		if (controllers == controller) //head?
			controllers = controllers.next;
		else
		{
			//n points to the node before controller
			var n = controllers;
			while (n.next != controller) n = n.next;
			
			assert(n.next != null);
			n.next = controller.next;
		}
		
		controller.next = null;
		controller.setObject(null);
	}
	
	public function findControllerOfType<T:Controller>(type:Int):T
	{
		var c = controllers;
		while (c != null)
		{
			if (c.type == type)
				return cast c;
			c = c.next;
		}
		return null;
	}
	
	public function updateControllers(dt:Float):Bool
	{
		if (controllers == null) return false;
		if (!controllersEnabled) return false;
		
		var someoneUpdated = false;
		var c = controllers, hook;
		while (c != null)
		{
			hook = c.next;
			if (c.update(dt)) someoneUpdated = true;
			c = hook;
		}
		return someoneUpdated;
	}
}