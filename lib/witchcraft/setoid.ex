import TypeClass

defclass Witchcraft.Setoid do
  @moduledoc ~S"""
  A setoid is a type with an equivalence relation.

  This is most useful when equivalence of some data is not the same as equality.

  Since some types have differing concepts of equality, this allows overriding
  the behaviour from `Kernel.==/2`. To get the Setoid `==` operator override,
  simply `use Witchcraft.Setoid`.

  ## Type Class

  An instance of `Witchcraft.Setoid` must define `Witchcraft.Setoid.equivalent?/2`

      Setoid [equivalent?/2]
  """

  alias __MODULE__
  import Kernel, except: [==: 2, !=: 2]

  defmacro __using__(opts \\ []) do
    overrides = [==: 2, !=: 2]
    excepts = Keyword.get(opts, :except, [])

    if Access.get(opts, :override_kernel, true) do
      kernel_imports = Macro.escape(except: overrides -- excepts)
      module_imports = Macro.escape(except: excepts)

      quote do
        import Kernel, unquote(kernel_imports)
        import unquote(__MODULE__), unquote(module_imports)
      end
    else
      module_imports = Macro.escape(except: Enum.uniq(overrides ++ excepts))

      quote do
        import unquote(__MODULE__), unquote(module_imports)
      end
    end
  end

  @type t :: any()

  where do
    @doc ~S"""
    Compare two setoids and determine if they are equivalent.

    Aliased as `==`.

    ## Examples

        iex> equivalent?(1, 2)
        false

        iex> import Kernel, except: [==: 2, !=: 2]
        ...> %{a: 1} == %{a: 1, b: 2}
        false

        equivalent?(%Maybe.Just{just: 42}, %Maybe.Nothing{})
        #=> false

    ### Equivalence not equality

        baby_harry = %Wizard{name: "Harry Potter", age: 10}
        old_harry  = %Wizard{name: "Harry Potter", age: 17}

        def chosen_one?(some_wizard), do: equivalent?(baby_harry, some_wizard)

        chosen_one?(old_harry)
        #=> true

    """
    @spec equivalent?(Setoid.t(), Setoid.t()) :: boolean()
    def equivalent?(a, b)
  end

  defalias a == b, as: :equivalent?

  @doc """
  The opposite of `equivalent?/2`.

  ## Examples

      iex> nonequivalent?(1, 2)
      true

  """
  @spec nonequivalent?(Setoid.t(), Setoid.t()) :: boolean()
  def nonequivalent?(a, b), do: not equivalent?(a, b)

  defalias a != b, as: :nonequivalent?

  properties do
    def reflexivity(data) do
      a = generate(data)
      Setoid.equivalent?(a, a)
    end

    def symmetry(data) do
      a = generate(data)
      b = generate(data)

      equal?(Setoid.equivalent?(a, b), Setoid.equivalent?(b, a))
    end

    def transitivity(data) do
      a = b = c = generate(data)
      Setoid.equivalent?(a, b) and Setoid.equivalent?(b, c) and Setoid.equivalent?(a, c)
    end
  end
end

definst Witchcraft.Setoid, for: Integer do
  def equivalent?(int, num), do: Kernel.==(int, num)
end

definst Witchcraft.Setoid, for: Float do
  def equivalent?(float, num), do: Kernel.==(float, num)
end

definst Witchcraft.Setoid, for: BitString do
  def equivalent?(string_a, string_b), do: Kernel.==(string_a, string_b)
end

definst Witchcraft.Setoid, for: Tuple do
  def equivalent?(tuple_a, tuple_b), do: Kernel.==(tuple_a, tuple_b)
end

definst Witchcraft.Setoid, for: List do
  def equivalent?(list_a, list_b), do: Kernel.==(list_a, list_b)
end

definst Witchcraft.Setoid, for: Map do
  def equivalent?(map_a, map_b), do: Kernel.==(map_a, map_b)
end

definst Witchcraft.Setoid, for: MapSet do
  def equivalent?(a, b), do: MapSet.equal?(a, b)
end
