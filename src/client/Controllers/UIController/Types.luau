--!strict

export type Context = {
	Controllers: { [string]: any },
	Open: (string) -> (),
	Close: (string) -> (),
	Notify: (string) -> (),
}

export type Screen = {
	Gui: GuiObject,
	Modal: boolean,
	StartsOpen: boolean,
	Open: (self: any) -> (),
	Close: (self: any) -> (),
	Destroy: (self: any) -> (),
	Update: ((self: any, data: any) -> ())?,
	Trove: any,
}

return {}
