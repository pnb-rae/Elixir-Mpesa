defmodule MpesaWeb.Stklive.Index do
  @moduledoc """
  The `MpesaWeb.Stklive.Index` LiveView is used to test the STK push functionality for M-Pesa integration.

  This LiveView handles the rendering of the form and processes the events related to 
  M-Pesa STK push interactions, including validation and submission of parameters.


  """
  use MpesaWeb, :live_view

  alias Mpesa.MpesaStk
  alias Mpesa.StkForm
  alias Mpesa.TransactionStatusChecker

  require Logger

  def mount(_params, _session, socket) do
    initial_changeset = StkForm.changeset(%{}, %{})

    {:ok,
     socket
     |> assign(:form, to_form(initial_changeset, as: "stk_form"))}
  end

  def handle_event(
        "validate",
        %{"stk_form" => %{"Phone_number" => phone_number, "amount" => amount}},
        socket
      ) do
    # Use a plain map as data
    data = %{}

    # Build the changeset
    changeset = StkForm.changeset(data, %{:Phone_number => phone_number, :amount => amount})

    {:noreply, assign(socket, form: to_form(changeset, action: :validate, as: "stk_form"))}
  end

  def handle_event(
        "pay",
        %{"stk_form" => %{"Phone_number" => phone_number, "amount" => amount}},
        socket
      ) do
    payment_initiation = MpesaStk.initiate_payment(phone_number, amount)

    case payment_initiation do
      {:ok, response_body} ->
        checkout_request_id = response_body["CheckoutRequestID"]

        case recursive_check_status(checkout_request_id, 200) do
          {:ok, response} ->
            {:noreply,
             socket
             |> put_flash(:info, response)
             |> push_navigate(to: "/stk-test")}

          {:error, message} ->
            {:noreply,
             socket
             |> put_flash(:error, message)
             |> push_navigate(to: "/stk-test")}
        end

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to initiate payment")
         |> push_navigate(to: "/stk-test")}
    end
  end

  defp recursive_check_status(checkout_request_id, retries_remaining)
       when retries_remaining > 0 do
    case TransactionStatusChecker.check_status(checkout_request_id) do
      {:ok, "The transaction is being processed"} ->
        # Pause for 2 seconds before retrying
        Process.sleep(2000)
        Logger.info("Retrying transaction status check: #{retries_remaining} attempts remaining")
        recursive_check_status(checkout_request_id, retries_remaining - 1)

      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "Transaction failed"}
    end
  end

  defp recursive_check_status(_checkout_request_id, 0),
    do: {:error, "Failed to get a valid status after multiple attempts"}
end

## test- if phone number is valid
## test- if amount is greater than 0
## test- if phone number is invalid
## validate phone number
