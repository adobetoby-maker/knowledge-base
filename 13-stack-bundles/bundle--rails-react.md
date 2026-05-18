# Stack Bundle: Rails + React (Inertia or API Mode)

## Overview
Rails offers two paths with React: API mode (Rails serves JSON, React is a separate frontend app)
and Inertia mode (Rails renders pages directly without a separate API). API mode is the right choice
when the frontend is deployed separately or multiple clients (mobile, web) share the same backend.
Inertia mode works best when both layers are in the same repo and the same team.

## Implementation

### API Mode Setup
```bash
rails new myapp --api --database=postgresql
# --api: removes view layer, cookie-based middleware, asset pipeline
# Results in lighter middleware stack optimized for JSON responses
```
```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  before_action :authenticate_user!

  private

  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    @current_user = User.find_by_token(token)
    render json: { error: 'Unauthorized' }, status: :unauthorized unless @current_user
  end
end
```

### rack-cors for CORS
```ruby
# Gemfile
gem 'rack-cors'

# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch('ALLOWED_ORIGINS', 'http://localhost:5173').split(',')
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      expose: ['Authorization']   # expose custom headers to JS
  end
end
```

### Jbuilder or ActiveModelSerializer for JSON
```ruby
# Jbuilder (view-based, flexible)
# app/views/api/v1/posts/index.json.jbuilder
json.data do
  json.array! @posts do |post|
    json.id post.id
    json.title post.title
    json.author do
      json.id post.author.id
      json.name post.author.name
    end
    json.created_at post.created_at.iso8601
  end
end
json.meta do
  json.total @posts.total_count
  json.page params[:page]
end
```
```ruby
# ActiveModelSerializer (model-based, consistent)
class PostSerializer < ActiveModel::Serializer
  attributes :id, :title, :created_at
  belongs_to :author, serializer: UserSerializer
  has_many :comments, if: -> { scope&.admin? }  # conditionally include
end
```

### Sidekiq for Background Jobs
```ruby
# Gemfile
gem 'sidekiq'
gem 'sidekiq-scheduler'  # for recurring jobs

# app/jobs/send_welcome_email_job.rb
class SendWelcomeEmailJob < ApplicationJob
  queue_as :default
  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 5

  def perform(user_id)
    user = User.find(user_id)
    UserMailer.welcome(user).deliver_now
  end
end

# Enqueue
SendWelcomeEmailJob.perform_later(user.id)
SendWelcomeEmailJob.set(wait: 5.minutes).perform_later(user.id)
```
```bash
bundle exec sidekiq -q default -q mailers -c 5   # start worker with 5 concurrency
```

### Devise for Authentication
```ruby
# Gemfile: gem 'devise', gem 'devise-jwt' (for JWT in API mode)

# For API mode — JWT-based
class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :jwt_authenticatable,
         jwt_revocation_strategy: JwtDenylist
end

# routes.rb
devise_for :users, controllers: {
  sessions: 'api/v1/users/sessions',
  registrations: 'api/v1/users/registrations'
}
```
```ruby
# Returning the token in sessions controller
class Api::V1::Users::SessionsController < Devise::SessionsController
  respond_to :json

  private

  def respond_with(resource, _opts = {})
    render json: {
      user: UserSerializer.new(resource),
      token: request.env['warden-jwt_auth.token']
    }
  end
end
```

### RSpec + FactoryBot for Testing
```ruby
# spec/requests/api/v1/posts_spec.rb
require 'rails_helper'

RSpec.describe 'GET /api/v1/posts' do
  let(:user) { create(:user) }
  let(:headers) { { 'Authorization' => "Bearer #{user.generate_jwt}" } }

  before { create_list(:post, 3, author: user) }

  it 'returns paginated posts' do
    get '/api/v1/posts', headers: headers, params: { page: 1 }

    expect(response).to have_http_status(:ok)
    expect(json_body[:data].length).to eq(3)
    expect(json_body[:meta][:total]).to eq(3)
  end
end

# spec/factories/post.rb
FactoryBot.define do
  factory :post do
    title { Faker::Lorem.sentence }
    body { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    association :author, factory: :user
  end
end
```

## Key Rules
- Never call `render json: @post` on a model — always use a serializer or explicit attribute selection to avoid exposing sensitive fields
- CORS `credentials: true` requires the frontend to set `credentials: 'include'` on fetch requests
- RSpec request specs hit the full middleware stack — prefer them over controller specs for API testing
- Sidekiq jobs must be idempotent — they may run more than once (network failures, retries)
- ActiveRecord callbacks (after_create etc.) that call jobs must use `perform_later` not `perform_now` to avoid slow requests
- Database indexes: always add to foreign keys, email columns, and any column used in `where` clauses
- Never store sensitive data in Sidekiq job arguments — they are stored in Redis in plaintext; use IDs and look up the data in the job
