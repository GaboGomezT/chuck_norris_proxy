# Chuck Norris Proxy

A proxy service for Chuck Norris jokes API that provides rate limiting and API Key auth on top of the original API.

> **Live Demo**: You can try out the API immediately at [https://pbh6r29nvy.us-west-2.awsapprunner.com/docs](https://pbh6r29nvy.us-west-2.awsapprunner.com/docs). This interactive documentation allows you to:
>
> - Generate an API key
> - Test all endpoints directly from your browser
> - View request/response examples
> - Explore the available joke categories

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [API Documentation](#api-documentation)
- [Development](#development)
- [Contributing](#contributing)
- [Deployment](#deployment)

## Prerequisites

- Elixir 1.18 or later
- Erlang/OTP 24 or later
- Docker and Docker Compose (optional, for containerized deployment)
- Git

## Installation

### Local Development Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/chuck_norris_proxy.git
   cd chuck_norris_proxy
   ```

2. Install dependencies:

   ```bash
   mix deps.get
   ```

3. Start the application in development mode:

   ```bash
   # First compile the project
   mix compile

   # Then start the application
   mix run --no-halt
   ```

   The server will be available at `http://localhost:4000`

   > **Tip**: Once the server is running, you can access the interactive API documentation at `http://localhost:4000/docs`. This documentation interface allows you to:
   >
   > - Explore all available API endpoints
   > - Generate a new API key using the `/api/v1/keys` endpoint
   > - Test the API directly from the browser
   > - View request/response examples
   >
   > This is the easiest way to get started with the API and obtain your first API key.

### Docker Setup

#### Production

1. Build and run using Docker Compose:

   ```bash
   docker-compose up --build
   ```

   This will start the service in a container and make it available at `http://localhost:4000`

2. Or build and run using Docker directly:
   ```bash
   docker build -t chuck-norris-proxy .
   docker run -p 4000:4000 chuck-norris-proxy
   ```

#### Development with Docker

You can also use Docker for development by mounting your local code into the container. This allows you to make changes to the code and have them immediately reflected in the running container.

1. Edit `docker-compose.yml` and uncomment the volumes section:

   ```yaml
   volumes:
     - ./config:/app/config
     - ./lib:/app/lib
     - ./priv:/app/priv
   ```

2. Start the container in development mode:
   ```bash
   docker-compose up --build
   ```

Now you can:

- Edit files in your local `lib/`, `config/`, and `priv/` directories
- Changes will be immediately reflected in the container
- The container will automatically recompile when files change
- Use your local editor while still running in a containerized environment

## Configuration

The service can be configured using environment variables:

| Variable     | Description                           | Default | Required |
| ------------ | ------------------------------------- | ------- | -------- |
| `RATE_LIMIT` | Number of requests allowed per minute | `100`   | No       |

You can set these variables in a `.env` file or directly in your environment.

## API Documentation

### Authentication

All endpoints (except `/docs` and `/api/v1/keys`) require an API key to be included in the request headers:

```bash
curl -H "x-api-key: your-api-key" http://localhost:4000/api/v1/joke
```

To obtain an API key:

```bash
curl -X POST http://localhost:4000/api/v1/keys
# Response: { "key": "550e8400-e29b-41d4-a716-446655440000" }
```

### Available Endpoints

#### Documentation

- `GET /docs`
  - Returns HTML documentation
  - No authentication required
  - Example: `curl http://localhost:4000/docs`

#### Jokes API

1. Get Random Joke

   ```bash
   curl -H "x-api-key: your-api-key" http://localhost:4000/api/v1/joke
   ```

   Response:

   ```json
   {
   	"categories": ["science"],
   	"created_at": "2020-01-05 13:42:19.576875",
   	"id": "random-id",
   	"updated_at": "2020-01-05 13:42:19.576875",
   	"value": "Chuck Norris can divide by zero."
   }
   ```

2. Get Random Joke by Category

   ```bash
   curl -H "x-api-key: your-api-key" http://localhost:4000/api/v1/joke/science
   ```

   - Returns 404 if category not found
   - Available categories can be fetched from `/api/v1/categories`

3. Get Categories

   ```bash
   curl -H "x-api-key: your-api-key" http://localhost:4000/api/v1/categories
   ```

   Response:

   ```json
   [
   	"animal",
   	"career",
   	"celebrity",
   	"dev",
   	"explicit",
   	"fashion",
   	"food",
   	"history",
   	"money",
   	"movie",
   	"music",
   	"political",
   	"religion",
   	"science",
   	"sport",
   	"travel"
   ]
   ```

4. Search Jokes
   ```bash
   curl -H "x-api-key: your-api-key" "http://localhost:4000/api/v1/search?query=programming"
   ```
   - Required parameter: `query`
   - Returns 400 if query parameter is missing or empty
   - Response includes total count and matching jokes

### Rate Limiting

The API implements rate limiting to prevent abuse. The default limit is 100 requests per minute, but this can be configured using the `RATE_LIMIT` environment variable.

When rate limited, the API will return a 429 status code with a JSON response:

```json
{
	"error": "Rate limit exceeded. Try again in X seconds."
}
```

## Development

### Project Structure

- `lib/` - Contains the main application code
  - `router.ex` - API endpoint definitions
  - `plugs/` - Custom plugs for authentication and rate limiting
  - `api_client.ex` - Chuck Norris API client
  - `servers/` - GenServer implementations
- `config/` - Configuration files for different environments
- `test/` - Test files
- `priv/` - Static assets and database files
- `mix.exs` - Project configuration and dependencies

### Dependencies

The project uses the following main dependencies:

- `plug_cowboy` - Web server
- `jason` - JSON parsing
- `tesla` - HTTP client
- `envy` - Environment variable management
- `uuid` - UUID generation

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/chuck_norris_proxy/router_test.exs
```

## Deployment

### AWS Setup

#### 1. Create an ECR Repository

1. Log into the AWS Console and navigate to Amazon ECR
2. Click "Create repository"
3. Enter repository name: `erlang-api`
4. Keep default settings and click "Create repository"

#### 2. Create an App Runner Service

1. Navigate to AWS App Runner in the AWS Console
2. Click "Create service"
3. Select "Container registry" as the source
4. Choose "Amazon ECR" as the provider
5. Select the `erlang-api` repository
6. For the first deployment, you can skip the image tag selection since no images exist yet
7. Configure the service:
   - Service name: `chuck-norris-proxy` (or your preferred name)
   - Port: `4000` (matches our application port)
   - Environment variables (optional):
     - `RATE_LIMIT`: `100` (or your preferred limit)
8. Click "Create & deploy"

#### 3. CI/CD Pipeline

The repository includes a GitHub Actions workflow (`.github/workflows/deploy.yml`) that automatically:

- Runs tests
- Builds the Docker image
- Pushes the image to ECR with multiple tags:
  - `latest`
  - Git commit SHA
  - Timestamp
- The App Runner service will automatically deploy new images when they are pushed to ECR

To enable the CI/CD pipeline:

1. Add the following secrets to your GitHub repository:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
2. Ensure the AWS IAM user has permissions for:
   - ECR (push/pull images)
   - App Runner (deploy services)

The service will be available at the App Runner URL provided after deployment.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Write tests for new features
- Follow the existing code style
- Update documentation for any API changes
- Use meaningful commit messages
- Keep pull requests focused and small
