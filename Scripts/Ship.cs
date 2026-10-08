
using Godot;

public enum ModuleType
{
	Empty,
	Weapon,
	Cargo,
	Shield,
	Energy,
	Mining,
	Support
}

public partial class Ship : Node2D
{
	private const int GridSize = 3;
	private const float CellSize = 64.0f;
	private static readonly Vector2 ShipSize = new(GridSize * CellSize, GridSize * CellSize);
	private static readonly Color CellColor = new("3A3F46");
	private static readonly Color SelectionColor = Colors.Yellow;

	private readonly ShipCell[,] _cells = new ShipCell[GridSize, GridSize];
	private ShipCell _selectedCell;

	public override void _Ready()
	{
		InitializeCells();
		Position = (GetViewportRect().Size - ShipSize) * 0.5f;
		QueueRedraw();
	}

	public override void _Draw()
	{
		for (var row = 0; row < GridSize; row++)
		{
			for (var column = 0; column < GridSize; column++)
			{
				var cell = new Rect2(column * CellSize, row * CellSize, CellSize, CellSize);
				DrawRect(cell, CellColor, filled: true);
				DrawRect(cell, Colors.White, filled: false, width: 2.0f);

				if (ReferenceEquals(_cells[row, column], _selectedCell))
				{
					DrawRect(cell.Grow(-3.0f), SelectionColor, filled: false, width: 4.0f);
				}
			}
		}
	}

	public override void _UnhandledInput(InputEvent @event)
	{
		if (@event is not InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: true } mouseButton)
		{
			return;
		}

		if (TryGetCellAt(ToLocal(mouseButton.Position), out var cell))
		{
			_selectedCell = cell;
			GD.Print($"Selected cell: row={cell.Row}, column={cell.Column}, module={cell.ModuleType}");
		}
		else
		{
			_selectedCell = null;
		}

		QueueRedraw();
	}

	private void InitializeCells()
	{
		for (var row = 0; row < GridSize; row++)
		{
			for (var column = 0; column < GridSize; column++)
			{
				_cells[row, column] = new ShipCell(row, column, ModuleType.Empty);
			}
		}
	}

	private bool TryGetCellAt(Vector2 localPosition, out ShipCell cell)
	{
		cell = null;

		if (!new Rect2(Vector2.Zero, ShipSize).HasPoint(localPosition))
		{
			return false;
		}

		var column = Mathf.FloorToInt(localPosition.X / CellSize);
		var row = Mathf.FloorToInt(localPosition.Y / CellSize);

		if (row < 0 || row >= GridSize || column < 0 || column >= GridSize)
		{
			return false;
		}

		cell = _cells[row, column];
		return true;
	}

	private sealed class ShipCell
	{
		public ShipCell(int row, int column, ModuleType moduleType)
		{
			Row = row;
			Column = column;
			ModuleType = moduleType;
		}

		public int Row { get; }

		public int Column { get; }

		public ModuleType ModuleType { get; set; }
	}
}
