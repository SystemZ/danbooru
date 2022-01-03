require 'test_helper'

class DelayedJobsControllerTest < ActionDispatch::IntegrationTest
  context "The delayed jobs controller" do
    setup do
      @user = create(:admin_user)
      @job = create(:good_job)
    end

    context "index action" do
      should "render" do
        get delayed_jobs_path
        assert_response :success
      end
    end

    context "cancel action" do
      should "work" do
        GoodJob::ActiveJobJob.any_instance.stubs(:status).returns(:queued)
        put_auth cancel_delayed_job_path(@job), @user, xhr: true
        assert_response :success
      end
    end

    context "retry action" do
      should "work" do
        @job.head_execution.active_job.class.stubs(:queue_adapter).returns(GoodJob::Adapter.new)
        GoodJob::ActiveJobJob.any_instance.stubs(:status).returns(:discarded)
        put_auth retry_delayed_job_path(@job), @user, xhr: true
        assert_response :success
      end
    end

    context "run action" do
      should "work" do
        GoodJob::ActiveJobJob.any_instance.stubs(:status).returns(:queued)
        put_auth run_delayed_job_path(@job), @user, xhr: true
        assert_response :success
      end
    end

    context "destroy action" do
      should "work" do
        delete_auth delayed_job_path(@job), @user, xhr: true
        assert_response :success
      end
    end
  end
end
