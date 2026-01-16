defmodule Mpesa.TransactionStatusChecker do
  @moduledoc """
  A module responsible for checking the status of a transaction with the Mpesa API.
  """

  alias Mpesa.MpesaAuth

  require Logger

  @pass_key System.get_env("MPESA_PASS_KEY")
  @short_code "174379"

  def check_status(checkout_request_id) do
    {:ok, mpesa_token} = MpesaAuth.generate_token()
    headers = build_headers(mpesa_token)
    body = generate_body(checkout_request_id)

    response =
      Finch.build(:post, url(), headers, body)
      |> Finch.request(Mpesa.Finch)

    case response do
      {:ok, %Finch.Response{status: 200, body: resp_body}} ->
        Logger.info("Suceessfully checked transaction status")
        process_result_code(resp_body |> Jason.decode!() |> Map.get("ResultCode"))

      {:ok, %Finch.Response{status: 400, body: resp_body}} ->
        resp_body |> Jason.decode!()

      {:ok, %Finch.Response{status: 500, body: resp_body}} ->
        error_message = resp_body |> Jason.decode!() |> Map.get("errorMessage")
        {:ok, error_message}

      {:ok, %Finch.Response{status: _status, body: resp_body}} ->
        resp_body |> Jason.decode!()

      {:error, _reason} ->
        {:error, "Failed to check transaction status"}
    end
  end

  @doc false
  defp url do
    "https://sandbox.safaricom.co.ke/mpesa/stkpushquery/v1/query"
  end

  def build_headers(token) do
    [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]
  end

  @doc false
  defp generate_body(checkout_request_id) do
    timestamp = get_timestamp()
    password = generate_stk_password()

    %{
      BusinessShortCode: @short_code,
      Password: password,
      Timestamp: timestamp,
      CheckoutRequestID: checkout_request_id
    }
    |> Jason.encode!()
  end

  @doc false
  defp generate_stk_password do
    timestamp = get_timestamp()
    Base.encode64("#{@short_code}#{@pass_key}#{timestamp}")
  end

  @doc false
  defp get_timestamp do
    Timex.local()
    |> Timex.format!("{YYYY}{0M}{0D}{h24}{m}{s}")
  end

  @doc false
  defp process_result_code("0"), do: {:ok, "Payment made successfully"}

  defp process_result_code("1"), do: {:error, "Balance is insufficient"}

  defp process_result_code("26"), do: {:error, "System busy, Try again in a short while"}

  defp process_result_code("2001"), do: {:error, "Wrong Pin entered"}

  defp process_result_code("1001"), do: {:error, "Unable to lock subscriber"}

  defp process_result_code("1025"),
    do:
      {:error,
       "An error occurred while processing the request please try again after 2-3 minutes"}

  defp process_result_code("1019"), do: {:error, "Transaction expired. No MO has been received"}

  defp process_result_code("9999"),
    do:
      {:error,
       "An error occurred while processing the request please try again after 2-3 minutes"}

  defp process_result_code("1032"), do: {:error, "Request cancelled by user"}

  defp process_result_code("1037"), do: {:error, "No response from the user"}

  defp process_result_code("SFC_IC0003"), do: {:error, "Payment timeout"}

  defp process_result_code(unknown), do: unknown
end
