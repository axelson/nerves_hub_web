defmodule NervesHubWeb.API.DeviceController do
  use NervesHubWeb, :api_controller

  alias NervesHub.AuditLogs
  alias NervesHub.Devices
  alias NervesHub.Devices.DeviceCertificate
  alias NervesHubWeb.Endpoint

  action_fallback(NervesHubWeb.API.FallbackController)

  plug(:validate_role, [product: :delete] when action in [:delete])
  plug(:validate_role, [product: :write] when action in [:create, :update])
  plug(:validate_role, [product: :write] when action in [:reboot, :reconnect, :code])
  plug(:validate_role, [product: :read] when action in [:index, :show, :auth])

  def index(%{assigns: %{org: org, product: product}} = conn, params) do
    opts = %{
      pagination: Map.get(params, "pagination", %{}),
      filters: Map.get(params, "filters", %{})
    }

    page = Devices.get_devices_by_org_id_and_product_id(org.id, product.id, opts)
    pagination = Map.take(page, [:page_number, :page_size, :total_entries, :total_pages])

    conn
    |> assign(:devices, page.entries)
    |> assign(:pagination, pagination)
    |> render("index.json")
  end

  def create(%{assigns: %{org: org, product: product}} = conn, params) do
    params =
      params
      |> Map.put("org_id", org.id)
      |> Map.put("product_id", product.id)

    with {:ok, device} <- Devices.create_device(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.device_path(conn, :show, org.name, product.name, device.identifier)
      )
      |> render("show.json", device: device)
    end
  end

  def show(%{assigns: %{org: org}} = conn, %{"device_identifier" => identifier}) do
    with {:ok, device} <- Devices.get_device_by_identifier(org, identifier) do
      render(conn, "show.json", device: device)
    end
  end

  def delete(%{assigns: %{org: org}} = conn, %{
        "device_identifier" => identifier
      }) do
    {:ok, device} = Devices.get_device_by_identifier(org, identifier)
    {:ok, _device} = Devices.delete_device(device)

    send_resp(conn, :no_content, "")
  end

  def update(%{assigns: %{org: org}} = conn, %{"device_identifier" => identifier} = params) do
    with {:ok, device} <- Devices.get_device_by_identifier(org, identifier),
         {:ok, updated_device} <- Devices.update_device(device, params) do
      conn
      |> put_status(201)
      |> render("show.json", device: updated_device)
    end
  end

  def auth(%{assigns: %{org: org}} = conn, %{"certificate" => cert64}) do
    with {:ok, cert_pem} <- Base.decode64(cert64),
         {:ok, cert} <- X509.Certificate.from_pem(cert_pem),
         {:ok, %DeviceCertificate{device_id: device_id}} <-
           Devices.get_device_certificate_by_x509(cert),
         {:ok, device} <- Devices.get_device_by_org(org, device_id) do
      conn
      |> put_status(200)
      |> render("show.json", device: device)
    else
      _e ->
        conn
        |> send_resp(403, Jason.encode!(%{status: "Unauthorized"}))
    end
  end

  def reboot(conn, _params) do
    %{device: device, user: user} = conn.assigns

    AuditLogs.audit!(
      user,
      device,
      :update,
      "user #{user.username} rebooted device #{device.identifier}",
      %{reboot: true}
    )

    Endpoint.broadcast_from(self(), "device:#{device.id}", "reboot", %{})

    send_resp(conn, 200, "Success")
  end

  def reconnect(conn, _params) do
    Endpoint.broadcast_from(self(), "device:#{conn.assigns.device.id}", "reconnect", %{})
    send_resp(conn, 200, "Success")
  end

  def code(conn, %{"body" => body}) do
    device = conn.assigns.device

    body
    |> String.graphemes()
    |> Enum.map(fn character ->
      Endpoint.broadcast_from!(self(), "console:#{device.id}", "dn", %{"data" => character})
    end)

    Endpoint.broadcast_from!(self(), "console:#{device.id}", "dn", %{"data" => "\r"})

    send_resp(conn, 200, "Success")
  end
end
