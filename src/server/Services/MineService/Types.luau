--!strict

export type Rock = {
	Part: BasePart,
	Hp: number,
	MaxHp: number,
	Value: number,
	Column: number,
	Row: number,
}

export type Zone = {
	Folder: Folder,
	Centre: Vector3,
	Slot: number,
	Rocks: { [number]: Rock },
	Remaining: number,
	Value: number,
	Elapsed: number,
	LastHits: { [number]: number },
	MoveElapsed: number,
}

return {}
