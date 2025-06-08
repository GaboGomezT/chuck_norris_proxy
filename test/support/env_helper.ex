defmodule ChuckNorrisProxy.Test.EnvHelper do
  @moduledoc """
  Helper functions for managing environment variables in tests.
  """

  @doc """
  Temporarily sets an environment variable for the duration of a test.
  Automatically restores the original value when the test completes.

  ## Examples

      with_env("RATE_LIMIT", "5", fn ->
        # Test code that needs RATE_LIMIT=5
      end)
  """
  def with_env(key, value, test_func) when is_function(test_func, 0) do
    original_value = System.get_env(key)
    System.put_env(key, value)

    try do
      test_func.()
    after
      restore_env(key, original_value)
    end
  end

  @doc """
  Temporarily removes an environment variable for the duration of a test.
  Automatically restores the original value when the test completes.

  ## Examples

      without_env("RATE_LIMIT", fn ->
        # Test code that needs RATE_LIMIT to be unset
      end)
  """
  def without_env(key, test_func) when is_function(test_func, 0) do
    original_value = System.get_env(key)
    System.delete_env(key)

    try do
      test_func.()
    after
      restore_env(key, original_value)
    end
  end

  defp restore_env(_key, nil), do: :ok

  defp restore_env(key, original_value) do
    System.put_env(key, original_value)
  end
end
